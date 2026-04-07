{-# LANGUAGE OverloadedStrings #-}

module Lucee.Parse.Extension.Html
  ( findExtensionContainerByName
  , extractMetadataFromContainer
  , parseUrlToExtension
  , findExtensionsSection
  , findExtensionContainers
  , parseExtensionSection
  , extractExtensionMetadata
  , extractExtensionName
  , extractExtensionUuid
  , extractExtensionDescription
  , extractVersionSections
  , extractVersionsFromSection
  , findVersionEntries
  , determineVersionTypeFromHeader
  , parseVersionEntry
  , extractVersionInfo
  , parseMinLuceeVersion
  ) where

import Data.Maybe (mapMaybe)
import Data.Text (Text)
import qualified Data.Text as T
import Text.HTML.TagSoup (Tag(..), sections, (~==))

import Lucee.Types
import Lucee.Constants
import Lucee.Parse.Common (parseVersionFromUrl, extractFirstUrl)
import Lucee.Parse.Extension.Url (parseExtensionFromUrl, sanitizeExtensionName)

-- | Find HTML container for specific extension name
findExtensionContainerByName :: Text -> [Tag Text] -> Maybe [Tag Text]
findExtensionContainerByName targetName tags = 
  let extSection = findExtensionsSection tags
      containers = findAllContainers extSection
  in findMatchingContainer targetName containers
  where
    findAllContainers section = 
      sections (~== TagOpen ("div" :: String) [("class", "container")]) section
    
    findMatchingContainer target containers = 
      case filter (containerMatchesName target) containers of
        (container:_) -> Just container
        [] -> Nothing
    
    containerMatchesName target container = 
      any (urlContainsName target) (extractUrlsFromContainer container)
    
    extractUrlsFromContainer container = 
      [url | TagOpen "a" attrs <- container, ("href", url) <- attrs, ".lex" `T.isSuffixOf` url]
    
    urlContainsName target url = 
      let fileName = T.takeWhileEnd (/= '/') url
          baseName = T.dropEnd lexExtensionLength fileName
      in case T.splitOn "-" baseName of
           (name:_) -> name == target
           [] -> False

-- | Extract metadata from HTML container
extractMetadataFromContainer :: Text -> Maybe [Tag Text] -> (Text, Text, Text)
extractMetadataFromContainer fallbackName Nothing = 
  (fallbackName, defaultExtensionDescription, "")
extractMetadataFromContainer fallbackName (Just container) = 
  let displayName = maybe fallbackName id (extractExtensionName container)
      description = maybe defaultExtensionDescription id (extractExtensionDescription container)  
      uuid = maybe "" id (extractExtensionUuid container)
  in (displayName, description, uuid)

-- | Parse a single URL to Extension record
parseUrlToExtension :: Text -> Text -> Text -> Text -> Maybe Extension
parseUrlToExtension displayName description uuid url = do
  (name, version, versionType) <- parseExtensionFromUrl url
  let sanitizedName = sanitizeExtensionName name  -- Use parsed name from URL, not displayName from HTML
  
  pure $ Extension
    { extName = sanitizedName
    , extDisplayName = displayName
    , extVersion = version
    , extVersionType = versionType
    , extDescription = description
    , extDownloadUrl = url
    , extUuid = uuid
    , extMinLuceeVersion = Nothing -- Will be extracted from container if available
    , extSha256Hash = Nothing
    }

-- | Find the main extensions section in the HTML
findExtensionsSection :: [Tag Text] -> [Tag Text]
findExtensionsSection tags = 
  let sections = dropWhile (not . isExtensionsSectionStart) tags
  in takeWhile (not . isExtensionsSectionEnd) sections
  where
    isExtensionsSectionStart (TagOpen "div" attrs) = ("id", "ext") `elem` attrs
    isExtensionsSectionStart _ = False
    
    isExtensionsSectionEnd (TagOpen "div" attrs) = 
      any (\(_, v) -> "footer" `T.isInfixOf` v) attrs
    isExtensionsSectionEnd _ = False

-- | Find individual extension containers within the extensions section
-- This function is now used by findExtensionContainerByName for metadata extraction
findExtensionContainers :: [Tag Text] -> [[Tag Text]]
findExtensionContainers tags = 
  sections (~== TagOpen ("div" :: String) [("class", "container")]) tags

-- | Parse a single extension container into multiple Extension records (one per version)
parseExtensionSection :: [Tag Text] -> Maybe Extension
parseExtensionSection tags = do
  (displayName, uuid) <- extractExtensionMetadata tags
  description <- extractExtensionDescription tags
  
  -- Extract all versions from all version sections
  let versionSections = extractVersionSections tags
      allVersions = concatMap (extractVersionsFromSection displayName uuid description) versionSections
  
  -- Return the first stable version found, or first version if no stable
  case filter isStableVersion allVersions ++ allVersions of
    (ext:_) -> Just ext
    [] -> Nothing
  where
    isStableVersion ext = extVersionType ext == Release

-- | Extract extension name and UUID from the container header
extractExtensionMetadata :: [Tag Text] -> Maybe (Text, Text)
extractExtensionMetadata tags = do
  displayName <- extractExtensionName tags
  uuid <- extractExtensionUuid tags
  pure (displayName, uuid)

-- | Extract extension display name from the title
extractExtensionName :: [Tag Text] -> Maybe Text
extractExtensionName tags = 
  case findTitleText tags of
    Just title -> Just $ T.strip $ T.replace "Extension" "" title
    Nothing -> Nothing
  where
    findTitleText [] = Nothing
    findTitleText (TagOpen "span" attrs : TagText text : _)
      | ("class", "head1 title") `elem` attrs = Just text
    findTitleText (_ : rest) = findTitleText rest

-- | Extract extension UUID from permalink ID
extractExtensionUuid :: [Tag Text] -> Maybe Text
extractExtensionUuid tags = 
  case findPermalinkId tags of
    Just uuid -> Just $ T.strip uuid
    Nothing -> Nothing
  where
    findPermalinkId [] = Nothing
    findPermalinkId (TagOpen "div" attrs : _)
      | ("class", "permalinkHover") `elem` attrs = 
          lookup "id" attrs
    findPermalinkId (_ : rest) = findPermalinkId rest

-- | Extract extension description from the container
extractExtensionDescription :: [Tag Text] -> Maybe Text
extractExtensionDescription tags = 
  case findDescriptionText tags of
    Just desc -> Just $ T.take maxDescriptionLength $ T.strip desc
    Nothing -> Just defaultExtensionDescription -- Fallback
  where
    findDescriptionText [] = Nothing
    findDescriptionText (TagOpen "p" attrs : TagText text : _)
      | ("class", "fontStyle ml-2") `elem` attrs = Just text
    findDescriptionText (_ : rest) = findDescriptionText rest

-- | Extract version sections (Releases, RCs/Betas, Snapshots)
extractVersionSections :: [Tag Text] -> [[Tag Text]]
extractVersionSections tags = 
  let versionColumns = sections (~== TagOpen ("div" :: String) []) tags
  in filter hasVersionContent versionColumns
  where
    hasVersionContent column = 
      any isVersionHeader column && any isVersionEntry column
    
    isVersionHeader (TagText text) = 
      "Releases" `T.isInfixOf` text || 
      "RCs" `T.isInfixOf` text || 
      "Betas" `T.isInfixOf` text ||
      "Snapshots" `T.isInfixOf` text
    isVersionHeader _ = False
    
    isVersionEntry (TagOpen "a" attrs) = 
      any (\(_, url) -> luceeExtensionBaseUrl `T.isPrefixOf` url && lexExtension `T.isSuffixOf` url) attrs
    isVersionEntry _ = False

-- | Extract versions from a single version section
extractVersionsFromSection :: Text -> Text -> Text -> [Tag Text] -> [Extension]
extractVersionsFromSection displayName uuid description tags = 
  let versionEntries = findVersionEntries tags
      versionType = determineVersionTypeFromHeader tags
  in mapMaybe (parseVersionEntry displayName uuid description versionType) versionEntries

-- | Find version entries (download links) in a version section
findVersionEntries :: [Tag Text] -> [[Tag Text]]
findVersionEntries tags = 
  let linkSections = sections (~== TagOpen ("a" :: String) []) tags
  in filter hasLexDownload linkSections
  where
    hasLexDownload section = 
      any isLexLink section
    
    isLexLink (TagOpen "a" attrs) = 
      any (\(_, url) -> luceeExtensionBaseUrl `T.isPrefixOf` url && lexExtension `T.isSuffixOf` url) attrs
    isLexLink _ = False

-- | Determine version type from section header
determineVersionTypeFromHeader :: [Tag Text] -> VersionType
determineVersionTypeFromHeader tags = 
  case findHeaderText tags of
    Just header
      | "Releases" `T.isInfixOf` header -> Release
      | "RCs" `T.isInfixOf` header || "Betas" `T.isInfixOf` header -> RC -- Treat both as RC for simplicity
      | "Snapshots" `T.isInfixOf` header -> Beta -- Map Snapshots to Beta for now
    _ -> Release -- Default fallback

  where
    findHeaderText [] = Nothing
    findHeaderText (TagText text : _)
      | any (`T.isInfixOf` text) ["Releases", "RCs", "Betas", "Snapshots"] = Just text
    findHeaderText (_ : rest) = findHeaderText rest

-- | Parse a single version entry into an Extension
parseVersionEntry :: Text -> Text -> Text -> VersionType -> [Tag Text] -> Maybe Extension
parseVersionEntry displayName uuid description versionType tags = do
  (downloadUrl, version, minLuceeVersion) <- extractVersionInfo tags
  let name = sanitizeExtensionName displayName
  
  pure $ Extension
    { extName = name
    , extDisplayName = displayName
    , extVersion = version
    , extVersionType = versionType
    , extDescription = description
    , extDownloadUrl = downloadUrl
    , extUuid = uuid
    , extMinLuceeVersion = minLuceeVersion
    , extSha256Hash = Nothing
    }

-- | Extract version information from version entry tags
extractVersionInfo :: [Tag Text] -> Maybe (Text, Text, Maybe Text)
extractVersionInfo tags = do
  downloadUrl <- extractFirstUrl tags
  version <- parseVersionFromUrl downloadUrl
  let minLuceeVersion = parseMinLuceeVersion tags
  pure (downloadUrl, version, minLuceeVersion)

-- | Parse minimum Lucee version from title attribute
parseMinLuceeVersion :: [Tag Text] -> Maybe Text
parseMinLuceeVersion tags = 
  case [title | TagOpen "a" attrs <- tags, ("title", title) <- attrs] of
    (title:_) -> extractLuceeVersionFromTitle title
    [] -> Nothing
  where
    extractLuceeVersionFromTitle title
      | "Requires Lucee " `T.isPrefixOf` title = 
          Just $ T.takeWhile (/= ' ') $ T.drop (T.length "Requires Lucee ") title
      | otherwise = Nothing