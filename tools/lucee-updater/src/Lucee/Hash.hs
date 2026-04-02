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
import Control.Monad.Except (ExceptT(..), liftIO, throwError)
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as M
import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.Encoding as TE
import qualified Data.ByteString.Lazy as BL
import System.Process.Typed (proc, readProcessStdout_, ExitCode(..))

import Lucee.Types

-- | Compute SHA256 hash using nix-prefetch-url (IO boundary)
computeHash :: Text -> UpdateM Text
computeHash url = do
  result <- liftIO $ try @IOError $ readProcessStdout_ (proc "nix-prefetch-url" [T.unpack url])
  
  case result of
    Left ex -> throwError $ ProcessError $ "nix-prefetch-url failed for " <> url <> ": " <> T.pack (show ex)
    Right output -> 
          let hash = T.strip (TE.decodeUtf8 $ BL.toStrict output)
      in if isValidSha256 hash 
         then pure hash
         else throwError $ ValidationError $ "Invalid SHA256 hash for " <> url <> ": " <> hash

-- | Compute hashes for all artifacts in a version (IO boundary)
computeHashesForVersion :: LuceeVersion -> UpdateM LuceeVersion
computeHashesForVersion version = do
  hashMap <- computeHashesParallel (M.toList $ lvArtifacts version)
  pure $ version { lvSha256Hashes = M.fromList hashMap }

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
      pure $ case result of
        Left ex -> Left $ ProcessError $ "Hash computation failed for " <> url <> ": " <> T.pack (show ex)
        Right output -> 
          let hash = T.strip (TE.decodeUtf8 $ BL.toStrict output)
          in if isValidSha256 hash
             then Right (artifactType, hash)
             else Left $ ValidationError $ "Invalid hash for " <> url

-- | Pure SHA256 validation
isValidSha256 :: Text -> Bool
isValidSha256 hash = 
  T.length hash == 52 &&  -- Nix SHA256 format: "sha256-" + 43 chars
  "sha256-" `T.isPrefixOf` hash &&
  T.all isValidBase64Char (T.drop 7 hash)

-- | Pure base64 character validation  
isValidBase64Char :: Char -> Bool
isValidBase64Char c = 
  (c >= 'A' && c <= 'Z') || 
  (c >= 'a' && c <= 'z') || 
  (c >= '0' && c <= '9') || 
  c == '+' || c == '/' || c == '='

-- | Pure hash validation for consistency
validateHash :: Text -> Either UpdateError Text
validateHash hash = 
  if isValidSha256 hash
    then Right hash  
    else Left $ ValidationError $ "Invalid SHA256 format: " <> hash