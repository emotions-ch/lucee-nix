{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TypeApplications #-}

module Lucee.Hash
  ( computeHash
  , computeHashesForVersion
  , computeHashesParallel
  , computeHashesForExtension
  , computeHashesForExtensions
  ) where

import Control.Concurrent.Async (mapConcurrently)
import Control.Exception (try)
import System.IO.Error (IOError)
import Control.Monad.Except (ExceptT(..), throwError, catchError)
import Control.Monad.IO.Class (liftIO)
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as M
import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.Encoding as TE
import qualified Data.ByteString.Lazy as BL
import System.Process.Typed (proc, readProcessStdout_, ExitCode(..))

import Lucee.Types
import Lucee.Validation (isValidSha256, validateHash, isValidExtensionUrl)

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

-- | Compute hashes for all artifacts in a version (IO boundary)
computeHashesForVersion :: LuceeVersion -> UpdateM LuceeVersion
computeHashesForVersion version = do
  -- Use sequential processing for better error reporting
  hashPairs <- mapM computeSingleHash (M.toList $ lvArtifacts version)
  let hashMap = M.fromList hashPairs
  pure $ version { lvSha256Hashes = hashMap }
  where
    computeSingleHash :: (ArtifactType, Text) -> UpdateM (ArtifactType, Text)
    computeSingleHash (artifactType, url) = do
      hash <- computeHash url
      pure (artifactType, hash)

-- | Compute hashes in parallel for performance (IO boundary)  
computeHashesParallel :: [(ArtifactType, Text)] -> UpdateM [(ArtifactType, Text)]
computeHashesParallel artifacts = do
  results <- liftIO $ mapConcurrently computeArtifactHash artifacts
  
  -- Check all results for errors
  case sequence results of
    Left err -> throwError err
    Right hashes -> pure hashes
  
  where
    computeArtifactHash :: (ArtifactType, Text) -> IO (Either UpdateError (ArtifactType, Text))
    computeArtifactHash (artifactType, url) = do
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

-- | Compute SHA256 hash for a single extension (IO boundary)
computeHashesForExtension :: Extension -> UpdateM Extension
computeHashesForExtension extension = do
  -- Check if URL looks like a valid .lex file URL
  let url = extDownloadUrl extension
  if isValidExtensionUrl url
    then do
      -- Try to compute hash, but catch and handle errors gracefully
      hashResult <- (computeHash url >>= pure . Just) `catchError` (\_ -> do
        liftIO $ putStrLn $ "⚠️  Skipping hash for " <> T.unpack (extName extension) <> " due to hash computation error: " <> T.unpack url
        pure Nothing)
      pure $ extension { extSha256Hash = hashResult }
    else do
      -- Skip non-.lex URLs (likely documentation links)
      liftIO $ putStrLn $ "⚠️  Skipping invalid extension URL for " <> T.unpack (extName extension) <> ": " <> T.unpack url
      pure $ extension { extSha256Hash = Nothing }

-- | Compute hashes for multiple extensions in parallel (IO boundary)
computeHashesForExtensions :: [Extension] -> UpdateM [Extension]
computeHashesForExtensions extensions = do
  -- Use sequential processing to avoid overwhelming the server
  traverse computeHashesForExtension extensions