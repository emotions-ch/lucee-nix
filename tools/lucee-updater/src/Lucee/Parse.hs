{-# LANGUAGE OverloadedStrings #-}

module Lucee.Parse
  ( parseVersions
  , parseExtensions  
  , parseVersionString
  , extractDownloadUrls
  ) where

import Data.Map.Strict (Map)
import qualified Data.Map.Strict as M
import Data.Maybe (mapMaybe)
import Data.Text (Text)
import qualified Data.Text as T
import Text.HTML.TagSoup (Tag(..), parseTags, sections, (~==))

import Lucee.Types

-- | Pure function to parse all versions from HTML
parseVersions :: Text -> Either UpdateError [LuceeVersion]
parseVersions html = 
  let tags = parseTags html
      h2Sections = sections (~== TagOpen ("h2" :: String) []) tags
      versions = mapMaybe parseVersionFromH2Section h2Sections
      -- Remove duplicates by version number, keeping the first occurrence
      uniqueVersions = removeDuplicateVersions versions
  in Right uniqueVersions

-- | Remove duplicate versions, keeping the first occurrence
removeDuplicateVersions :: [LuceeVersion] -> [LuceeVersion]
removeDuplicateVersions versions = 
  let seen = []
      go [] acc = reverse acc
      go (v:vs) acc = 
        if lvVersion v `elem` map lvVersion acc
        then go vs acc  -- Skip duplicate
        else go vs (v:acc)  -- Keep first occurrence
  in go versions []

-- | Parse a version from an H2 section (e.g. "Release 7.0.2.106")  
parseVersionFromH2Section :: [Tag Text] -> Maybe LuceeVersion
parseVersionFromH2Section tags = do
  (version, vtype) <- extractVersionFromH2Header tags
  artifacts <- extractArtifactsFromSectionForVersion tags version
  pure $ LuceeVersion 
    { lvVersion = version
    , lvVersionType = vtype
    , lvArtifacts = artifacts
    , lvSha256Hashes = M.empty -- Will be filled by hash computation
    }

-- | Extract artifacts from the section, but only those that match the specific version
extractArtifactsFromSectionForVersion :: [Tag Text] -> Text -> Maybe (Map ArtifactType Text)
extractArtifactsFromSectionForVersion tags version = 
  let links = extractDownloadLinksForVersion tags version
      artifactMap = M.fromList $ mapMaybe classifyArtifactLink links
  in if M.null artifactMap then Nothing else Just artifactMap

-- | Extract download links that contain the specific version number
extractDownloadLinksForVersion :: [Tag Text] -> Text -> [Text]
extractDownloadLinksForVersion tags version = 
  let allUrls = [url | TagOpen "a" attrs <- tags,
                      ("href", url) <- attrs,
                      "https://cdn.lucee.org/" `T.isPrefixOf` url]
      -- Only keep URLs that contain the version number
      versionUrls = filter (T.isInfixOf version) allUrls
  in versionUrls

-- | Extract version and type from H2 header text
extractVersionFromH2Header :: [Tag Text] -> Maybe (Text, VersionType)
extractVersionFromH2Header tags = do
  headerText <- findH2Text tags
  parseH2HeaderText headerText

-- | Find the text content of H2 tag
findH2Text :: [Tag Text] -> Maybe Text
findH2Text [] = Nothing
findH2Text (TagOpen "h2" _ : TagText text : _) = Just text
findH2Text (_ : rest) = findH2Text rest

-- | Parse H2 header text like "Release 7.0.2.106" or "Release Candidate 7.0.3.43-RC"
parseH2HeaderText :: Text -> Maybe (Text, VersionType)
parseH2HeaderText headerText
  | "Release Candidate" `T.isPrefixOf` headerText = do
      versionWithSuffix <- T.stripPrefix "Release Candidate " headerText
      let cleanVersion = T.strip $ T.replace "-RC" "" versionWithSuffix
      pure (cleanVersion, RC)
  | "Release " `T.isPrefixOf` headerText = do
      version <- T.stripPrefix "Release " headerText  
      pure (T.strip version, Release)
  | "Beta" `T.isPrefixOf` headerText = do
      versionWithSuffix <- T.stripPrefix "Beta " headerText
      let cleanVersion = T.strip $ T.replace "-BETA" "" versionWithSuffix  
      pure (cleanVersion, Beta)
  | otherwise = Nothing

-- | Extract artifacts from the section following an H2 header
extractArtifactsFromSection :: [Tag Text] -> Maybe (Map ArtifactType Text)
extractArtifactsFromSection tags = 
  let links = extractDownloadLinks tags
      artifactMap = M.fromList $ mapMaybe classifyArtifactLink links
  in if M.null artifactMap then Nothing else Just artifactMap

-- | Extract download links from li > a tags in the current section
extractDownloadLinks :: [Tag Text] -> [Text]
extractDownloadLinks tags = 
  let urls = [url | TagOpen "a" attrs <- tags,
                   ("href", url) <- attrs,
                   "https://cdn.lucee.org/" `T.isPrefixOf` url]
  in urls

-- | Pure version number extraction (legacy function - kept for compatibility)
extractVersionNumber :: [Tag Text] -> Maybe Text
extractVersionNumber tags = 
  let versionLinks = [url | TagOpen "a" attrs <- tags,
                           ("href", url) <- attrs,
                           "lucee-" `T.isInfixOf` url]
  in case versionLinks of
    (url:_) -> parseVersionFromUrl url
    [] -> Nothing

-- | Pure version parsing from URL
parseVersionFromUrl :: Text -> Maybe Text  
parseVersionFromUrl url
  | "lucee-zero-" `T.isInfixOf` url = 
      let afterPrefix = T.drop 1 $ T.dropWhile (/= '-') $ 
                       T.dropWhile (/= '-') $ 
                       T.dropWhile (/= '-') url
          beforeExtension = T.takeWhile (/= '.') afterPrefix
      in if T.null beforeExtension then Nothing else Just beforeExtension
  | otherwise = Nothing

-- | Pure artifact extraction from version block (legacy function)
extractArtifacts :: [Tag Text] -> Maybe (Map ArtifactType Text)
extractArtifacts tags = 
  let links = [url | TagOpen "a" attrs <- tags,
                    ("href", url) <- attrs,
                    "https://cdn.lucee.org/" `T.isPrefixOf` url]
      artifactMap = M.fromList $ mapMaybe classifyArtifactLink links
  in if M.null artifactMap then Nothing else Just artifactMap

-- | Classify artifact links by URL pattern
classifyArtifactLink :: Text -> Maybe (ArtifactType, Text) 
classifyArtifactLink url
  | "lucee-zero-" `T.isInfixOf` url && ".jar" `T.isSuffixOf` url = Just (LuceeZero, url)
  | "lucee-light-" `T.isInfixOf` url && ".jar" `T.isSuffixOf` url = Just (LuceeLight, url)
  | "/lucee-" `T.isInfixOf` url && ".jar" `T.isSuffixOf` url = Just (LuceeJar, url)
  | otherwise = Nothing

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