{-# LANGUAGE OverloadedStrings #-}

module Lucee.Parse
  ( parseVersions
  , parseExtensions  
  , parseVersionString
  , extractDownloadUrls
  ) where

import Data.Map.Strict (Map)
import qualified Data.Map.Strict as M
import Data.Maybe (mapMaybe, catMaybes)
import Data.Text (Text)
import qualified Data.Text as T
import Text.HTML.TagSoup (Tag(..), parseTags, sections, partitions, (~==))
import Text.HTML.TagSoup.Tree (parseTree, TagTree(..))

import Lucee.Types

-- | Pure function to parse all versions from HTML
parseVersions :: Text -> Either UpdateError [LuceeVersion]
parseVersions html = 
  let tags = parseTags html
      releaseVersions = parseVersionsByType Release tags
      rcVersions = parseVersionsByType RC tags  
      betaVersions = parseVersionsByType Beta tags
  in Right $ concat [releaseVersions, rcVersions, betaVersions]

-- | Pure function to parse versions of a specific type
parseVersionsByType :: VersionType -> [Tag Text] -> [LuceeVersion]
parseVersionsByType vtype tags =
  let sectionTags = findVersionSection vtype tags
      versionBlocks = partitions isVersionBlock sectionTags
  in mapMaybe (parseVersionBlock vtype) versionBlocks

-- | Pure function to find the section for a specific version type
findVersionSection :: VersionType -> [Tag Text] -> [Tag Text] 
findVersionSection vtype tags =
  let h2Sections = sections (~== TagOpen ("h2" :: String) []) tags
      targetSection = case vtype of
        Release -> findSectionContaining ["Release", "Stable"] h2Sections
        RC -> findSectionContaining ["Release Candidate", "RC"] h2Sections  
        Beta -> findSectionContaining ["Beta"] h2Sections
  in concat targetSection

-- | Pure function to find section containing target text
findSectionContaining :: [Text] -> [[Tag Text]] -> [[Tag Text]]
findSectionContaining targets sections = 
  filter (any (containsAnyText targets) . take 10) sections

-- | Pure predicate for version blocks  
isVersionBlock :: Tag Text -> Bool
isVersionBlock (TagOpen "div" attrs) = 
  any (\(name, val) -> name == "class" && "version" `T.isInfixOf` val) attrs
isVersionBlock _ = False

-- | Pure function to parse a single version block
parseVersionBlock :: VersionType -> [Tag Text] -> Maybe LuceeVersion
parseVersionBlock vtype tags = do
  version <- extractVersionNumber tags
  artifacts <- extractArtifacts tags
  pure $ LuceeVersion 
    { lvVersion = version
    , lvVersionType = vtype
    , lvArtifacts = artifacts
    , lvSha256Hashes = M.empty -- Will be filled by hash computation
    }

-- | Pure version number extraction
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

-- | Pure artifact extraction from version block
extractArtifacts :: [Tag Text] -> Maybe (Map ArtifactType Text)
extractArtifacts tags = 
  let links = [(text, url) | TagOpen "a" attrs <- tags,
                            ("href", url) <- attrs,
                            TagText text <- tags]
      artifactMap = M.fromList $ mapMaybe parseArtifactLink links
  in if M.null artifactMap then Nothing else Just artifactMap

-- | Pure artifact link parsing
parseArtifactLink :: (Text, Text) -> Maybe (ArtifactType, Text)
parseArtifactLink (linkText, url)
  | "lucee-zero" `T.isInfixOf` url = Just (LuceeZero, url)
  | "lucee-light" `T.isInfixOf` url = Just (LuceeLight, url) 
  | "lucee.jar" `T.isInfixOf` linkText = Just (LuceeJar, url)
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
  case parseVersionType input of
    Just vtype -> 
      let cleanVersion = T.replace "-RC" "" $ T.replace "-BETA" "" input
      in if isValidVersion cleanVersion 
         then Right (cleanVersion, vtype)
         else Left (ParseError $ "Invalid version format: " <> input)
    Nothing -> Left (ParseError $ "Unknown version type: " <> input)

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

-- | Pure helper: check if text contains any of the target strings
containsAnyText :: [Text] -> Tag Text -> Bool
containsAnyText targets (TagText text) = 
  any (`T.isInfixOf` T.toLower text) (map T.toLower targets)
containsAnyText _ _ = False