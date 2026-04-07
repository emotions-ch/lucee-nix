{-# LANGUAGE OverloadedStrings #-}

module Lucee.Parse.Jar
  ( parseVersions
  , parseVersionFromH2Section
  , extractVersionFromH2Header
  , parseH2HeaderText
  , extractArtifactsFromSectionForVersion
  , classifyArtifactLink
  , extractArtifacts
  , extractArtifactsFromSection
  , extractVersionNumber
  , removeDuplicateVersions
  , findH2Text
  ) where

import Data.Map.Strict (Map)
import qualified Data.Map.Strict as M
import Data.Maybe (mapMaybe)
import Data.Text (Text)
import qualified Data.Text as T
import Text.HTML.TagSoup (Tag(..), parseTags, sections, (~==))

import Lucee.Types
import Lucee.Parse.Common (parseVersionFromUrl, extractVersionFilteredUrls, extractLuceeJarUrls)

-- | Pure function to parse all Lucee jar versions from HTML
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

-- | Parse a Lucee jar version from an H2 section (e.g. "Release 7.0.2.106")  
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

-- | Extract Lucee jar artifacts from the section, but only those that match the specific version
extractArtifactsFromSectionForVersion :: [Tag Text] -> Text -> Maybe (Map ArtifactType Text)
extractArtifactsFromSectionForVersion tags version = 
  let links = extractVersionFilteredUrls version tags
      artifactMap = M.fromList $ mapMaybe classifyArtifactLink links
  in if M.null artifactMap then Nothing else Just artifactMap

-- | Extract version and type from H2 header text for Lucee jars
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

-- | Extract Lucee jar artifacts from the section following an H2 header
extractArtifactsFromSection :: [Tag Text] -> Maybe (Map ArtifactType Text)
extractArtifactsFromSection tags = 
  let links = extractLuceeJarUrls tags
      artifactMap = M.fromList $ mapMaybe classifyArtifactLink links
  in if M.null artifactMap then Nothing else Just artifactMap

-- | Pure version number extraction from Lucee jar links (legacy function - kept for compatibility)
extractVersionNumber :: [Tag Text] -> Maybe Text
extractVersionNumber tags = 
  let versionLinks = [url | TagOpen "a" attrs <- tags,
                           ("href", url) <- attrs,
                           "lucee-" `T.isInfixOf` url]
  in case versionLinks of
    (url:_) -> parseVersionFromUrl url
    [] -> Nothing

-- | Pure artifact extraction from Lucee jar version block (legacy function)
extractArtifacts :: [Tag Text] -> Maybe (Map ArtifactType Text)
extractArtifacts tags = 
  let links = [url | TagOpen "a" attrs <- tags,
                    ("href", url) <- attrs,
                    "https://cdn.lucee.org/" `T.isPrefixOf` url]
      artifactMap = M.fromList $ mapMaybe classifyArtifactLink links
  in if M.null artifactMap then Nothing else Just artifactMap

-- | Classify Lucee jar artifact links by URL pattern
classifyArtifactLink :: Text -> Maybe (ArtifactType, Text) 
classifyArtifactLink url
  | "lucee-zero-" `T.isInfixOf` url && ".jar" `T.isSuffixOf` url = Just (LuceeZero, url)
  | "lucee-light-" `T.isInfixOf` url && ".jar" `T.isSuffixOf` url = Just (LuceeLight, url)
  | "/lucee-" `T.isInfixOf` url && ".jar" `T.isSuffixOf` url = Just (LuceeJar, url)
  | otherwise = Nothing