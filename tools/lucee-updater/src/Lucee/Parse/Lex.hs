{-# LANGUAGE OverloadedStrings #-}

module Lucee.Parse.Lex
  ( parseExtensions,
    parseExtensionFromUrl,
    groupExtensionUrls,
    selectBestVersions,
    extractExtensionMetadata,
    parseMinLuceeVersion,
    findExtensionContainerByName,
  )
where

import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.Maybe (mapMaybe)
import Data.Text (Text)
import qualified Data.Text as T
import Lucee.Constants (defaultExtensionDescription)
import Lucee.Parse.Common (extractAllLexUrls)
import Lucee.Parse.Extension.Html (extractExtensionMetadata, extractMetadataFromContainer, findExtensionContainerByName, parseMinLuceeVersion, parseUrlToExtension)
import Lucee.Parse.Extension.Url (groupExtensionUrls, parseExtensionFromUrl)
import Lucee.Parse.Extension.Version (selectBestVersions)
import Lucee.Types
import Text.HTML.TagSoup (Tag (..), parseTags)

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
  let -- Try to find the HTML container for this extension (for metadata)
      containerMaybe = findExtensionContainerByName extName tags

      -- Create unique descriptions for each extension to prevent cross-contamination
      (displayName, description, uuid) = case containerMaybe of
        Just container -> extractMetadataFromContainer extName (Just container)
        Nothing ->
          -- Create a unique, meaningful description for each extension
          let uniqueDesc = createUniqueDescription extName
           in (extName, uniqueDesc, "")

      -- Parse each URL into an Extension
      extensions = mapMaybe (parseUrlToExtension displayName description uuid) urls

      -- Return best version (single extension)
      bestExtensions = selectBestVersions extensions
   in bestExtensions
  where
    -- Create meaningful descriptions when container extraction fails
    createUniqueDescription name =
      let cleanName = T.replace "_" " " $ T.replace "extension" "" name
          trimmedName = T.strip cleanName
       in if T.null trimmedName
            then defaultExtensionDescription
            else "Lucee " <> trimmedName <> " extension"
