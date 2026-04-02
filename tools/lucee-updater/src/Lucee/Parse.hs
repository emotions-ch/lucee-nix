{-# LANGUAGE OverloadedStrings #-}

module Lucee.Parse
  ( -- Re-export jar-specific functions for compatibility
    parseVersions
  , parseExtensions  
  , parseVersionString
  , extractDownloadUrls
  ) where

import Data.Maybe (mapMaybe)
import Data.Text (Text)
import qualified Data.Text as T
import Text.HTML.TagSoup (Tag(..), parseTags, sections, (~==))

import Lucee.Types
import qualified Lucee.Parse.Jar as Jar

-- | Re-export jar parsing function for compatibility
parseVersions :: Text -> Either UpdateError [LuceeVersion]
parseVersions = Jar.parseVersions

-- | Pure extension parsing (placeholder for comprehensive implementation)
parseExtensions :: Text -> Either UpdateError [Extension]
parseExtensions html = 
  let tags = parseTags html
      extensionSections = findExtensionSections tags
  in Right $ mapMaybe parseExtensionSection extensionSections

-- | Pure function to find extension sections
findExtensionSections :: [Tag Text] -> [[Tag Text]]
findExtensionSections tags = 
  let extensionMarkers = sections (~== TagOpen ("div" :: String) [("class", "extension")]) tags
  in take 100 extensionMarkers -- Limit to prevent memory issues

-- | Pure extension section parsing  
parseExtensionSection :: [Tag Text] -> Maybe Extension
parseExtensionSection tags = do
  name <- extractExtensionName tags
  version <- extractExtensionVersion tags
  description <- extractExtensionDescription tags  
  downloadUrl <- extractExtensionDownloadUrl tags
  pure $ Extension name version description downloadUrl Nothing

-- | Pure extension name extraction
extractExtensionName :: [Tag Text] -> Maybe Text
extractExtensionName tags = 
  case [text | TagText text <- tags, not (T.null (T.strip text))] of
    (name:_) -> Just (T.strip name)
    [] -> Nothing

-- | Pure extension version extraction  
extractExtensionVersion :: [Tag Text] -> Maybe Text
extractExtensionVersion tags = 
  let versionPattern = [T.strip text | TagText text <- tags,
                       T.any (\c -> c == '.' && (c >= '0' && c <= '9')) text]
  in case versionPattern of
    (version:_) -> Just version
    [] -> Just "latest" -- Fallback

-- | Pure extension description extraction
extractExtensionDescription :: [Tag Text] -> Maybe Text  
extractExtensionDescription tags = 
  case [T.strip text | TagText text <- tags, T.length (T.strip text) > 20] of
    (desc:_) -> Just (T.take 200 desc) -- Limit description length
    [] -> Just "Lucee Extension" -- Fallback

-- | Pure extension download URL extraction
extractExtensionDownloadUrl :: [Tag Text] -> Maybe Text
extractExtensionDownloadUrl tags = 
  case [url | TagOpen "a" attrs <- tags,
             ("href", url) <- attrs,
             ".lex" `T.isSuffixOf` url] of
    (url:_) -> Just url
    [] -> Nothing

-- | Pure version string parsing with validation
parseVersionString :: Text -> Either UpdateError (Text, VersionType)
parseVersionString input = 
  case determineVersionType input of
    Just vtype -> 
      let cleanVersion = T.replace "-RC" "" $ T.replace "-BETA" "" input
      in if isValidVersion cleanVersion 
         then Right (cleanVersion, vtype)
         else Left (ParseError $ "Invalid version format: " <> input)
    Nothing -> Left (ParseError $ "Unknown version type: " <> input)

-- | Determine version type from version string
determineVersionType :: Text -> Maybe VersionType
determineVersionType input
  | "-RC" `T.isSuffixOf` input = Just RC
  | "-BETA" `T.isSuffixOf` input = Just Beta  
  | otherwise = Just Release -- Default to Release for numeric versions

-- | Pure version validation
isValidVersion :: Text -> Bool  
isValidVersion version = 
  let parts = T.splitOn "." version
  in length parts >= 3 && all isNumericPart parts

-- | Pure numeric part validation
isNumericPart :: Text -> Bool
isNumericPart part = not (T.null part) && T.all (\c -> c >= '0' && c <= '9') part

-- | Pure URL extraction for download links
extractDownloadUrls :: [Tag Text] -> [Text]
extractDownloadUrls tags = 
  [url | TagOpen "a" attrs <- tags,
        ("href", url) <- attrs,
        "https://cdn.lucee.org/" `T.isPrefixOf` url ||
        "https://ext.lucee.org/" `T.isPrefixOf` url]