{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TypeApplications #-}

module Lucee.Hash
  ( computeHash,
    computeHashesForVersion,
    computeHashesParallel,
    computeHashesParallelBounded,
    computeHashesForExtension,
    computeHashesForExtensions,
  )
where

import Control.Concurrent.Async (mapConcurrently)
import Control.Concurrent.QSem (newQSem, signalQSem, waitQSem)
import Control.Exception (try)
import Control.Monad.Except (ExceptT (..), catchError, throwError)
import Control.Monad.IO.Class (liftIO)
import qualified Data.ByteString.Lazy as BL
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as M
import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.Encoding as TE
import Lucee.Types
import Lucee.Validation (isValidExtensionUrl, isValidSha256, validateHash)
import System.IO.Error (IOError)
import System.Process.Typed (ExitCode (..), proc, readProcessStdout_)

-- | Compute SHA256 hash using nix-prefetch-url and convert to SRI format (IO boundary)
computeHash :: Text -> UpdateM Text
computeHash url = do
  result <- liftIO $ try @IOError $ readProcessStdout_ (proc "nix-prefetch-url" [T.unpack url])

  case result of
    Left ex -> throwError $ ProcessError $ "nix-prefetch-url failed for " <> url <> ": " <> T.pack (show ex)
    Right output ->
      let base32Hash = T.strip (TE.decodeUtf8 $ BL.toStrict output)
       in if isValidSha256 base32Hash
            then convertToSRI base32Hash
            else throwError $ ValidationError $ "Invalid SHA256 hash for " <> url <> ": " <> base32Hash

-- | Convert base32 hash to SRI format using nix hash command
convertToSRI :: Text -> UpdateM Text
convertToSRI base32Hash = do
  result <- liftIO $ try @IOError $ readProcessStdout_ (proc "nix" ["hash", "to-sri", "--type", "sha256", T.unpack base32Hash])

  case result of
    Left ex -> throwError $ ProcessError $ "nix hash to-sri failed: " <> T.pack (show ex)
    Right output ->
      let sriHash = T.strip (TE.decodeUtf8 $ BL.toStrict output)
       in if "sha256-" `T.isPrefixOf` sriHash
            then pure sriHash
            else throwError $ ValidationError $ "Invalid SRI hash format: " <> sriHash

-- | Compute hashes for all artifacts in a version using parallel processing (IO boundary)
computeHashesForVersion :: LuceeVersion -> UpdateM LuceeVersion
computeHashesForVersion version = do
  -- Use bounded parallel processing with conservative concurrency
  let artifacts = M.toList $ lvArtifacts version
  hashPairs <- computeHashesParallelBounded 3 artifacts -- Max 3 concurrent for CDN
  let hashMap = M.fromList hashPairs
  pure $ version {lvSha256Hashes = hashMap}

-- | Compute hashes in parallel with bounded concurrency (IO boundary)
computeHashesParallelBounded :: Int -> [(ArtifactType, Text)] -> UpdateM [(ArtifactType, Text)]
computeHashesParallelBounded maxConcurrency artifacts = do
  -- Create semaphore to limit concurrent operations
  semaphore <- liftIO $ newQSem maxConcurrency
  results <- liftIO $ mapConcurrently (computeArtifactHashBounded semaphore) artifacts

  -- Check all results for errors
  case sequence results of
    Left err -> throwError err
    Right hashes -> pure hashes
  where
    computeArtifactHashBounded sem (artifactType, url) = do
      -- Acquire semaphore before processing
      waitQSem sem
      result <- computeArtifactHashInternal (artifactType, url)
      -- Release semaphore after processing
      signalQSem sem
      pure result

    computeArtifactHashInternal :: (ArtifactType, Text) -> IO (Either UpdateError (ArtifactType, Text))
    computeArtifactHashInternal (artifactType, url) = do
      result <- try @IOError $ readProcessStdout_ (proc "nix-prefetch-url" [T.unpack url])
      case result of
        Left ex -> pure $ Left $ ProcessError $ "Hash computation failed for " <> url <> ": " <> T.pack (show ex)
        Right output ->
          let base32Hash = T.strip (TE.decodeUtf8 $ BL.toStrict output)
           in if isValidSha256 base32Hash
                then do
                  -- Convert to SRI format
                  sriResult <- try @IOError $ readProcessStdout_ (proc "nix" ["hash", "to-sri", "--type", "sha256", T.unpack base32Hash])
                  case sriResult of
                    Left ex -> pure $ Left $ ProcessError $ "SRI conversion failed for " <> url <> ": " <> T.pack (show ex)
                    Right sriOutput ->
                      let sriHash = T.strip (TE.decodeUtf8 $ BL.toStrict sriOutput)
                       in if "sha256-" `T.isPrefixOf` sriHash
                            then pure $ Right (artifactType, sriHash)
                            else pure $ Left $ ValidationError $ "Invalid SRI hash for " <> url <> ": " <> sriHash
                else pure $ Left $ ValidationError $ "Invalid base32 hash for " <> url

-- | Legacy parallel function - kept for backward compatibility
computeHashesParallel :: [(ArtifactType, Text)] -> UpdateM [(ArtifactType, Text)]
computeHashesParallel = computeHashesParallelBounded 3

-- | Compute SHA256 hash for a single extension (IO boundary)
computeHashesForExtension :: Extension -> UpdateM Extension
computeHashesForExtension extension = do
  -- Check if URL looks like a valid .lex file URL
  let url = extDownloadUrl extension
  if isValidExtensionUrl url
    then do
      -- Try to compute hash, but catch and handle errors gracefully
      hashResult <-
        (computeHash url >>= pure . Just)
          `catchError` ( \_ -> do
                           liftIO $ putStrLn $ "⚠️  Skipping hash for " <> T.unpack (extName extension) <> " due to hash computation error: " <> T.unpack url
                           pure Nothing
                       )
      pure $ extension {extSha256Hash = hashResult}
    else do
      -- Skip non-.lex URLs (likely documentation links)
      liftIO $ putStrLn $ "⚠️  Skipping invalid extension URL for " <> T.unpack (extName extension) <> ": " <> T.unpack url
      pure $ extension {extSha256Hash = Nothing}

-- | Compute hashes for multiple extensions with bounded parallel processing (IO boundary)
computeHashesForExtensions :: [Extension] -> UpdateM [Extension]
computeHashesForExtensions extensions = do
  -- Use bounded parallel processing to avoid overwhelming the server
  -- Conservative limit of 2 concurrent requests for extension server
  semaphore <- liftIO $ newQSem 2
  results <- liftIO $ mapConcurrently (computeExtensionHashBounded semaphore) extensions

  -- Filter out failures and return successful results
  pure $ map extractResult results
  where
    computeExtensionHashBounded sem extension = do
      waitQSem sem
      result <- computeExtensionHashInternal extension
      signalQSem sem
      pure result

    computeExtensionHashInternal :: Extension -> IO Extension
    computeExtensionHashInternal extension = do
      let url = extDownloadUrl extension
      if isValidExtensionUrl url
        then do
          -- Try to compute hash, but handle errors gracefully
          result <- try @IOError $ readProcessStdout_ (proc "nix-prefetch-url" [T.unpack url])
          case result of
            Left ex -> do
              putStrLn $ "⚠️  Skipping hash for " <> T.unpack (extName extension) <> " due to error: " <> show ex
              pure $ extension {extSha256Hash = Nothing}
            Right output -> do
              let base32Hash = T.strip (TE.decodeUtf8 $ BL.toStrict output)
              if isValidSha256 base32Hash
                then do
                  -- Convert to SRI format
                  sriResult <- try @IOError $ readProcessStdout_ (proc "nix" ["hash", "to-sri", "--type", "sha256", T.unpack base32Hash])
                  case sriResult of
                    Left _ -> pure $ extension {extSha256Hash = Nothing}
                    Right sriOutput ->
                      let sriHash = T.strip (TE.decodeUtf8 $ BL.toStrict sriOutput)
                       in if "sha256-" `T.isPrefixOf` sriHash
                            then pure $ extension {extSha256Hash = Just sriHash}
                            else pure $ extension {extSha256Hash = Nothing}
                else do
                  putStrLn $ "⚠️  Invalid hash for " <> T.unpack (extName extension)
                  pure $ extension {extSha256Hash = Nothing}
        else do
          putStrLn $ "⚠️  Skipping invalid extension URL for " <> T.unpack (extName extension) <> ": " <> T.unpack url
          pure $ extension {extSha256Hash = Nothing}

    extractResult :: Extension -> Extension
    extractResult = id
