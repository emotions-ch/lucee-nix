{-# LANGUAGE OverloadedStrings #-}

module Lucee.Parse.Lex
  ( parseExtensions
  , parseExtensionFromUrl
  , groupExtensionUrls
  , selectBestVersions
  , extractExtensionMetadata
  , parseMinLuceeVersion
  , findExtensionContainerByName
  ) where

import Data.Maybe (mapMaybe, catMaybes)
import Data.Text (Text)
import qualified Data.Text as T
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.List (nub, sortBy)
import Data.Ord (comparing, Down(..))
import Text.HTML.TagSoup (Tag(..), parseTags, sections, (~==), (~/=))
import Text.Regex.TDFA ((=~), getAllTextMatches)

import Lucee.Types
import Lucee.Parse.Common (parseVersionFromUrl, extractAllLexUrls, extractFirstUrl)

-- | Extract all .lex URLs from HTML using regex
-- | Parse extension name and version from .lex URL
parseExtensionFromUrl :: Text -> Maybe (Text, Text, VersionType)
parseExtensionFromUrl url = do
  -- Extract filename: https://ext.lucee.org/name-version.lex
  let fileName = T.takeWhileEnd (/= '/') url
  let baseName = T.dropEnd 4 fileName -- Remove .lex extension
  
  -- Split on dash and find where version starts
  case T.splitOn "-" baseName of
    [] -> Nothing
    [single] -> 
      -- Single part, treat as name with empty version  
      Just (single, "1.0.0", Release)
    parts -> 
      -- Find the last part that looks like a version (contains numbers or specific version keywords)
      let (nameParts, versionParts) = findVersionSplit (reverse parts)
          name = T.intercalate "-" (reverse nameParts)
          version = T.intercalate "-" (reverse versionParts)
          versionType = classifyExtensionVersion version
      in if T.null name 
         then -- Fallback: treat first part as name, rest as version
              case parts of
                (n:vs) -> Just (n, T.intercalate "-" vs, classifyExtensionVersion (T.intercalate "-" vs))
                [] -> Nothing
         else if T.null version
              then Just (name, "1.0.0", Release) -- Default version
              else Just (name, version, versionType)

-- | Find where to split name vs version parts
findVersionSplit :: [Text] -> ([Text], [Text])
findVersionSplit [] = ([], [])
findVersionSplit [single] = 
  -- For single part, if it looks like version, treat as version with empty name
  -- Otherwise treat as name with empty version
  if isVersionPart single
    then ([], [single])
    else ([single], [])
findVersionSplit (part:rest) 
  | isVersionPart part = 
      -- This part looks like version, include it and continue collecting version parts
      let (nameRest, versionRest) = findVersionSplit rest
      in (nameRest, part : versionRest)
  | otherwise = 
      -- This part looks like name, stop collecting version parts
      (part : rest, [])

-- | Check if a part looks like a version component
isVersionPart :: Text -> Bool
isVersionPart part = 
  -- Be more conservative about identifying version parts
  let lowerPart = T.toLower part
  in T.any (\c -> c >= '0' && c <= '9') part || -- Contains digits
     lowerPart `elem` ["snapshot", "beta", "rc", "alpha", "jre8", "jdk8", "ojdbc11", "jdbc4", "0001l"] ||
     -- Short numeric or dot-separated version parts
     (T.length part <= 3 && T.all (\c -> (c >= '0' && c <= '9') || c == '.') part && T.any (\c -> c >= '0' && c <= '9') part) ||
     -- Version pattern like "1.0.0" (must contain digits)
     (T.count "." part >= 1 && T.any (\c -> c >= '0' && c <= '9') part)

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
          baseName = T.dropEnd 4 fileName
      in case T.splitOn "-" baseName of
           (name:_) -> name == target
           [] -> False

-- | Group URLs by extension name with deduplication
groupExtensionUrls :: [Text] -> Map Text [Text]
groupExtensionUrls urls = 
  let parsedUrls = mapMaybe (\url -> do
        (name, version, versionType) <- parseExtensionFromUrl url
        return (name, url)) urls
      -- Apply both basicDedup and sanitization for consistent grouping
      groupedWithDedup = Map.fromListWith (++) [(sanitizeExtensionName (basicDedup name), [url]) | (name, url) <- parsedUrls]
  in groupedWithDedup
  where
    -- Enhanced deduplication: normalize extension names to remove common suffixes
    basicDedup name = 
      let lowerName = T.toLower name
      in if ".extension" `T.isSuffixOf` lowerName
         then T.dropEnd 10 lowerName -- Remove ".extension" suffix
         else if "-extension" `T.isSuffixOf` lowerName  
         then T.dropEnd 10 lowerName -- Remove "-extension" suffix
         else lowerName


-- | Parse all extensions from the HTML download page
parseExtensions :: Text -> Either UpdateError [Extension]
parseExtensions html = 
  let tags = parseTags html
      
      -- Phase 1: Extract all .lex URLs
      allUrls = extractAllLexUrls html
      
      -- Phase 2: Group by extension name with deduplication
      urlGroups = groupExtensionUrls allUrls
      
      -- Phase 3: For each extension, create Extension records
      extensions = concatMap (parseExtensionGroup tags) (Map.toList urlGroups)
      
  in Right extensions

-- | Parse extension group (name + URLs) into Extension records
parseExtensionGroup :: [Tag Text] -> (Text, [Text]) -> [Extension]
parseExtensionGroup tags (extName, urls) = 
  let -- Find the HTML container for this extension (for metadata) - make this optional
      containerMaybe = findExtensionContainerByName extName tags
      
      -- Extract metadata from container (if found), otherwise use defaults
      (displayName, description, uuid) = extractMetadataFromContainer extName containerMaybe
      
      -- Parse each URL into an Extension
      extensions = mapMaybe (parseUrlToExtension displayName description uuid) urls
      
      -- Return best version (single extension)
      bestExtensions = selectBestVersions extensions
      
  in bestExtensions

-- | Extract metadata from HTML container
extractMetadataFromContainer :: Text -> Maybe [Tag Text] -> (Text, Text, Text)
extractMetadataFromContainer fallbackName Nothing = 
  (fallbackName, "Lucee Extension", "")
extractMetadataFromContainer fallbackName (Just container) = 
  let displayName = maybe fallbackName id (extractExtensionName container)
      description = maybe "Lucee Extension" id (extractExtensionDescription container)  
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

-- | Select best versions from extension list (prefer stable, then latest)
selectBestVersions :: [Extension] -> [Extension]
selectBestVersions [] = []
selectBestVersions extensions =
  let -- Group by version type and sort properly within each type
      releaseVersions = sortExtensionsByVersion $ filter (\e -> extVersionType e == Release) extensions
      rcVersions = sortExtensionsByVersion $ filter (\e -> extVersionType e == RC) extensions  
      betaVersions = sortExtensionsByVersion $ filter (\e -> extVersionType e == Beta) extensions
      
  in -- Return ONLY the single best version (prefer release, fallback to RC, then Beta)  
     case releaseVersions of
       (best:_) -> [best]  -- Found release versions, take the newest
       [] -> case rcVersions of
         (best:_) -> [best]  -- No release, use newest RC
         [] -> case betaVersions of
           (best:_) -> [best]  -- No release/RC, use newest Beta
           [] -> []  -- No versions at all

-- | Sort extensions by version number (newest first)
sortExtensionsByVersion :: [Extension] -> [Extension]
sortExtensionsByVersion extensions = 
  sortBy (comparing (Down . parseVersionForComparison . extVersion)) extensions
  
-- | Parse version string into comparable format
-- This handles various version formats like "1.0.0.7", "extension-1.0.0", "jdbc-6.5.4", etc.
parseVersionForComparison :: Text -> [Int]
parseVersionForComparison version = 
  let -- Clean up version string by removing common prefixes/suffixes
      cleanVersion = T.toLower version
      withoutPrefixes = foldl (\v prefix -> if prefix `T.isPrefixOf` v then T.drop (T.length prefix) v else v) 
                             cleanVersion 
                             ["extension-", "jdbc-", "light-", "zero-"]
      withoutSuffixes = foldl (\v suffix -> if suffix `T.isSuffixOf` v then T.dropEnd (T.length suffix) v else v)
                             withoutPrefixes
                             ["-rc", "-beta", "-snapshot", "-alpha", ".jre8", ".jdk8", ".jdbc4", "ojdbc11", ".0001l"]
      -- Extract numeric parts separated by dots, dashes, or other separators
      numericParts = T.splitOn "." $ T.replace "-" "." withoutSuffixes
      -- Convert each part to integer, defaulting to 0 for non-numeric parts
      parsedParts = map parseVersionPart numericParts
  in if null parsedParts then [0] else parsedParts
  
-- | Parse individual version part, extracting numeric value
parseVersionPart :: Text -> Int
parseVersionPart part = 
  case T.unpack $ T.takeWhile (\c -> c >= '0' && c <= '9') part of
    "" -> 0
    numStr -> read numStr

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
    Just desc -> Just $ T.take 200 $ T.strip desc
    Nothing -> Just "Lucee Extension" -- Fallback
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
      any (\(_, url) -> "https://ext.lucee.org/" `T.isPrefixOf` url && ".lex" `T.isSuffixOf` url) attrs
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
      any (\(_, url) -> "https://ext.lucee.org/" `T.isPrefixOf` url && ".lex" `T.isSuffixOf` url) attrs
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

-- | Extract download URL from version entry
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

-- | Sanitize extension name for Nix identifier
sanitizeExtensionName :: Text -> Text
sanitizeExtensionName name = 
  let cleaned = T.toLower $ T.strip name
      sanitized = T.map sanitizeChar cleaned
      withoutSpaces = T.replace " " "-" sanitized
  in withoutSpaces
  where
    sanitizeChar c
      | c >= 'a' && c <= 'z' = c
      | c >= 'A' && c <= 'Z' = c
      | c >= '0' && c <= '9' = c
      | c == '.' = '_'
      | c == '-' = '_'
      | c == ' ' = '-'
      | otherwise = '_'

-- | Generate download URL for extension
makeExtensionDownloadUrl :: Text -> Text -> Text
makeExtensionDownloadUrl name version = 
  "https://ext.lucee.org/" <> name <> "-" <> version <> ".lex"

-- | Classify extension version type from version string
classifyExtensionVersion :: Text -> VersionType
classifyExtensionVersion version
  | "SNAPSHOT" `T.isSuffixOf` version = Beta -- Map SNAPSHOT to Beta for consistency
  | "-RC" `T.isSuffixOf` version = RC
  | "-BETA" `T.isSuffixOf` version = Beta
  | "BETA" `T.isSuffixOf` version = Beta
  | otherwise = Release