{-# LANGUAGE OverloadedStrings #-}

module Lucee.Parse.Extension.Url
  ( parseExtensionFromUrl,
    groupExtensionUrls,
    sanitizeExtensionName,
    makeExtensionDownloadUrl,
    classifyExtensionVersion,
  )
where

import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.Maybe (mapMaybe)
import Data.Text (Text)
import qualified Data.Text as T
import Lucee.Constants
import Lucee.Types

-- | Parse extension name and version from .lex URL
parseExtensionFromUrl :: Text -> Maybe (Text, Text, VersionType)
parseExtensionFromUrl url = do
  -- Extract filename: https://ext.lucee.org/name-version.lex
  let fileName = T.takeWhileEnd (/= '/') url
  let baseName = T.dropEnd lexExtensionLength fileName -- Remove .lex extension

  -- Split on dash and find where version starts
  case T.splitOn "-" baseName of
    [] -> Nothing
    [single] ->
      -- Single part, treat as name with empty version
      Just (single, defaultVersion, Release)
    parts ->
      -- Find the last part that looks like a version (contains numbers or specific version keywords)
      let (nameParts, versionParts) = findVersionSplit (reverse parts)
          name = T.intercalate "-" (reverse nameParts)
          version = T.intercalate "-" (reverse versionParts)
          versionType = classifyExtensionVersion version
       in if T.null name
            then -- Fallback: treat first part as name, rest as version
              case parts of
                (n : vs) -> Just (n, T.intercalate "-" vs, classifyExtensionVersion (T.intercalate "-" vs))
                [] -> Nothing
            else
              if T.null version
                then Just (name, defaultVersion, Release) -- Default version
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
findVersionSplit (part : rest)
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
   in T.any (\c -> c >= '0' && c <= '9') part
        || lowerPart `elem` versionKeywords -- Contains digits
        ||
        -- Short numeric or dot-separated version parts
        (T.length part <= 3 && T.all (\c -> (c >= '0' && c <= '9') || c == '.') part && T.any (\c -> c >= '0' && c <= '9') part)
        ||
        -- Version pattern like "1.0.0" (must contain digits)
        (T.count "." part >= 1 && T.any (\c -> c >= '0' && c <= '9') part)

-- | Group URLs by extension name with deduplication
groupExtensionUrls :: [Text] -> Map Text [Text]
groupExtensionUrls urls =
  let parsedUrls =
        mapMaybe
          ( \url -> do
              (name, version, versionType) <- parseExtensionFromUrl url
              return (name, url)
          )
          urls
      -- Apply both basicDedup and sanitization for consistent grouping
      groupedWithDedup = Map.fromListWith (++) [(sanitizeExtensionName (basicDedup name), [url]) | (name, url) <- parsedUrls]
   in groupedWithDedup
  where
    -- Enhanced deduplication: normalize extension names to remove common suffixes
    basicDedup name =
      let lowerName = T.toLower name
       in if ".extension" `T.isSuffixOf` lowerName
            then T.dropEnd extensionSuffixLength lowerName -- Remove ".extension" suffix
            else
              if "-extension" `T.isSuffixOf` lowerName
                then T.dropEnd extensionSuffixLength lowerName -- Remove "-extension" suffix
                else lowerName

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
  luceeExtensionBaseUrl <> name <> "-" <> version <> lexExtension

-- | Classify extension version type from version string
classifyExtensionVersion :: Text -> VersionType
classifyExtensionVersion version
  | "SNAPSHOT" `T.isSuffixOf` version = Beta -- Map SNAPSHOT to Beta for consistency
  | "-RC" `T.isSuffixOf` version = RC
  | "-BETA" `T.isSuffixOf` version = Beta
  | "BETA" `T.isSuffixOf` version = Beta
  | otherwise = Release
