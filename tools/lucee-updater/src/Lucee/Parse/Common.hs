{-# LANGUAGE OverloadedStrings #-}

module Lucee.Parse.Common
  ( parseVersionFromUrl
  , parseJarVersionFromUrl
  , parseLexVersionFromUrl
  ) where

import Data.Text (Text)
import qualified Data.Text as T

-- | Unified version parsing from URL with type detection
parseVersionFromUrl :: Text -> Maybe Text
parseVersionFromUrl url
  | ".jar" `T.isSuffixOf` url = parseJarVersionFromUrl url
  | ".lex" `T.isSuffixOf` url = parseLexVersionFromUrl url
  | otherwise = Nothing

-- | Parse Lucee JAR version from URL (e.g., "lucee-zero-7.0.2.106.jar")
parseJarVersionFromUrl :: Text -> Maybe Text  
parseJarVersionFromUrl url
  | "lucee-zero-" `T.isInfixOf` url = 
      let afterPrefix = T.drop 1 $ T.dropWhile (/= '-') $ 
                       T.dropWhile (/= '-') $ 
                       T.dropWhile (/= '-') url
          beforeExtension = T.takeWhile (/= '.') afterPrefix
      in if T.null beforeExtension then Nothing else Just beforeExtension
  | otherwise = Nothing

-- | Parse extension version from URL (e.g., "extension-name-1.0.0.lex")
parseLexVersionFromUrl :: Text -> Maybe Text
parseLexVersionFromUrl url = 
  let fileName = T.takeWhileEnd (/= '/') url
      baseName = T.dropEnd 4 fileName -- Remove .lex extension
      -- Extract version part after the last dash
      parts = T.splitOn "-" baseName
  in if length parts >= 2
     then Just $ T.intercalate "-" $ drop 1 $ reverse $ take 2 $ reverse parts
     else Nothing