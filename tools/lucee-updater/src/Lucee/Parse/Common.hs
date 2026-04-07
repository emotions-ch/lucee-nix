{-# LANGUAGE OverloadedStrings #-}

module Lucee.Parse.Common
  ( parseVersionFromUrl
  , parseJarVersionFromUrl
  , parseLexVersionFromUrl
  , extractDownloadUrls
  , extractUrlsWithFilter
  , extractLuceeJarUrls
  , extractLuceeExtensionUrls
  , extractVersionFilteredUrls
  , extractFirstUrl
  , extractAllLexUrls
  ) where

import Data.Text (Text)
import qualified Data.Text as T
import Text.HTML.TagSoup (Tag(..))
import Text.Regex.TDFA ((=~), getAllTextMatches)

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

-- | Extract URLs from HTML tags with domain filtering
extractDownloadUrls :: [Tag Text] -> [Text]
extractDownloadUrls tags = 
  [url | TagOpen "a" attrs <- tags,
        ("href", url) <- attrs,
        "https://cdn.lucee.org/" `T.isPrefixOf` url ||
        "https://ext.lucee.org/" `T.isPrefixOf` url]

-- | Generic URL extraction with custom filter predicate
extractUrlsWithFilter :: (Text -> Bool) -> [Tag Text] -> [Text]
extractUrlsWithFilter filterPredicate tags = 
  [url | TagOpen "a" attrs <- tags,
        ("href", url) <- attrs,
        filterPredicate url]

-- | Extract Lucee JAR URLs specifically (cdn.lucee.org domain)
extractLuceeJarUrls :: [Tag Text] -> [Text]
extractLuceeJarUrls = extractUrlsWithFilter ("https://cdn.lucee.org/" `T.isPrefixOf`)

-- | Extract Lucee extension URLs specifically (ext.lucee.org domain)  
extractLuceeExtensionUrls :: [Tag Text] -> [Text]
extractLuceeExtensionUrls = extractUrlsWithFilter ("https://ext.lucee.org/" `T.isPrefixOf`)

-- | Extract URLs filtered by version string
extractVersionFilteredUrls :: Text -> [Tag Text] -> [Text]
extractVersionFilteredUrls version tags =
  let allUrls = extractLuceeJarUrls tags
  in filter (T.isInfixOf version) allUrls

-- | Extract first URL from tags (for single URL scenarios)
extractFirstUrl :: [Tag Text] -> Maybe Text
extractFirstUrl tags = 
  case [url | TagOpen "a" attrs <- tags, ("href", url) <- attrs] of
    (url:_) -> Just url
    [] -> Nothing

-- | Extract all .lex URLs using regex pattern (for extension HTML parsing)
extractAllLexUrls :: Text -> [Text]
extractAllLexUrls html = 
  let pattern = "https://ext\\.lucee\\.org/[^\"]*\\.lex" :: String
      htmlString = T.unpack html
      allMatches = getAllTextMatches (htmlString =~ pattern) :: [String]
  in map T.pack allMatches