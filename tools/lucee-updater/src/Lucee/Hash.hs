{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TypeApplications #-}

module Lucee.Hash
  ( computeHash
  , computeHashesForVersion
  , computeHashesParallel
  , validateHash
  ) where

import Control.Concurrent.Async (mapConcurrently)
import Control.Exception (try)
import System.IO.Error (IOError)
import Control.Monad.Except (ExceptT(..), throwError)
import Control.Monad.IO.Class (liftIO)
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as M
import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.Encoding as TE
import qualified Data.ByteString.Lazy as BL
import System.Process.Typed (proc, readProcessStdout_, ExitCode(..))

import Lucee.Types

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

-- | Pure SHA256 validation (supports both old and new Nix hash formats)
isValidSha256 :: Text -> Bool
isValidSha256 hash 
  | T.length hash == 52 && "sha256-" `T.isPrefixOf` hash = 
      -- New SRI format: "sha256-" + 43 chars base64
      T.all isValidBase64Char (T.drop 7 hash)
  | T.length hash == 52 = 
      -- Old Nix format: 52 chars base32 
      T.all isValidNixBase32Char hash
  | otherwise = False

-- | Pure base64 character validation  
isValidBase64Char :: Char -> Bool
isValidBase64Char c = 
  (c >= 'A' && c <= 'Z') || 
  (c >= 'a' && c <= 'z') || 
  (c >= '0' && c <= '9') || 
  c == '+' || c == '/' || c == '='

-- | Pure Nix base32 hash character validation
isValidNixBase32Char :: Char -> Bool  
isValidNixBase32Char c = 
  (c >= 'a' && c <= 'z') || 
  (c >= '0' && c <= '9')

-- | Pure hash validation for consistency (accepts both base32 and SRI format)
validateHash :: Text -> Either UpdateError Text
validateHash hash 
  | "sha256-" `T.isPrefixOf` hash = 
      if T.length hash == 52 && T.all isValidBase64Char (T.drop 7 hash)
      then Right hash
      else Left $ ValidationError $ "Invalid SRI hash format: " <> hash
  | T.length hash == 52 && T.all isValidNixBase32Char hash = 
      Right hash  -- Accept base32 format too
  | otherwise = Left $ ValidationError $ "Invalid hash format: " <> hash