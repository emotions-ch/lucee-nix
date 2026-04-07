{-# LANGUAGE OverloadedStrings #-}

module Lucee.Parse
  ( -- Re-export jar-specific functions for compatibility
    parseVersions,
    parseExtensions,
    parseVersionString,
    extractDownloadUrls,
  )
where

import Data.Maybe (mapMaybe)
import Data.Text (Text)
import qualified Data.Text as T
import Lucee.Parse.Common (extractDownloadUrls)
import qualified Lucee.Parse.Jar as Jar
import qualified Lucee.Parse.Lex as Lex
import Lucee.Types
import Lucee.Validation (isNumericPart, isValidVersion)
import Text.HTML.TagSoup (Tag (..), parseTags, sections, (~==))

-- | Re-export jar parsing function for compatibility
parseVersions :: Text -> Either UpdateError [LuceeVersion]
parseVersions = Jar.parseVersions

-- | Re-export extension parsing function using Lex module
parseExtensions :: Text -> Either UpdateError [Extension]
parseExtensions = Lex.parseExtensions

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

-- | Pure version type checking
isVersionType :: VersionType -> Text -> Bool
isVersionType targetType version =
  parseVersionType version == Just targetType
