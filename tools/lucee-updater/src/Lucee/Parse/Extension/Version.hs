{-# LANGUAGE OverloadedStrings #-}

module Lucee.Parse.Extension.Version
  ( selectBestVersions,
    sortExtensionsByVersion,
    parseVersionForComparison,
  )
where

import Data.List (sortBy)
import Data.Ord (Down (..), comparing)
import Data.Text (Text)
import qualified Data.Text as T
import Lucee.Types

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
        (best : _) -> [best] -- Found release versions, take the newest
        [] -> case rcVersions of
          (best : _) -> [best] -- No release, use newest RC
          [] -> case betaVersions of
            (best : _) -> [best] -- No release/RC, use newest Beta
            [] -> [] -- No versions at all

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
      withoutPrefixes =
        foldl
          (\v prefix -> if prefix `T.isPrefixOf` v then T.drop (T.length prefix) v else v)
          cleanVersion
          ["extension-", "jdbc-", "light-", "zero-"]
      withoutSuffixes =
        foldl
          (\v suffix -> if suffix `T.isSuffixOf` v then T.dropEnd (T.length suffix) v else v)
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
