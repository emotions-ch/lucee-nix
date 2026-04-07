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

import Data.Maybe (mapMaybe)
import Data.Text (Text)
import qualified Data.Text as T
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Text.HTML.TagSoup (Tag(..), parseTags)

import Lucee.Types
import Lucee.Parse.Common (extractAllLexUrls)
import Lucee.Parse.Extension.Url (parseExtensionFromUrl, groupExtensionUrls)
import Lucee.Parse.Extension.Html (findExtensionContainerByName, extractMetadataFromContainer, parseUrlToExtension, extractExtensionMetadata, parseMinLuceeVersion)
import Lucee.Parse.Extension.Version (selectBestVersions)

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