{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE OverloadedStrings #-}

module Lucee.Types
  ( LuceeVersion (..),
    VersionType (..),
    ArtifactType (..),
    Extension (..),
    LuceeDefinitions (..),
    UpdateError (..),
    UpdateM,
    parseVersionType,
    renderVersionType,
    isVersionType,
  )
where

import Control.Exception (Exception)
import Control.Monad.Except (ExceptT)
import Data.Map.Strict (Map)
import Data.Text (Text)
import qualified Data.Text as T
import Data.Time (UTCTime)
import GHC.Generics (Generic)

-- | Core data types for Lucee artifacts
data LuceeVersion = LuceeVersion
  { -- | Version string like "7.0.2.106"
    lvVersion :: Text,
    -- | Release, RC, or Beta
    lvVersionType :: VersionType,
    -- | Download URLs for different artifacts
    lvArtifacts :: Map ArtifactType Text,
    -- | SHA256 hashes for artifacts
    lvSha256Hashes :: Map ArtifactType Text
  }
  deriving stock (Show, Eq, Generic)

-- | Version types we track (excludes Snapshots for stability)
data VersionType
  = Release
  | RC
  | Beta
  deriving stock (Show, Eq, Ord, Generic, Enum, Bounded)

-- | Different Lucee artifact types
data ArtifactType
  = -- | Minimal Lucee JAR without extensions
    LuceeZero
  | -- | Full Lucee JAR with bundled extensions
    LuceeJar
  | -- | Lightweight Lucee JAR
    LuceeLight
  deriving stock (Show, Eq, Ord, Generic, Enum, Bounded)

-- | Extension information
data Extension = Extension
  { -- | Extension name for Nix identifier
    extName :: Text,
    -- | Human-readable extension name
    extDisplayName :: Text,
    -- | Extension version
    extVersion :: Text,
    -- | Version type (Release, RC, Beta)
    extVersionType :: VersionType,
    -- | Extension description
    extDescription :: Text,
    -- | Download URL for .lex file
    extDownloadUrl :: Text,
    -- | Unique extension UUID
    extUuid :: Text,
    -- | Minimum required Lucee version
    extMinLuceeVersion :: Maybe Text,
    -- | SHA256 hash for verification
    extSha256Hash :: Maybe Text
  }
  deriving stock (Show, Eq, Generic)

-- | Complete definitions for Nix generation
data LuceeDefinitions = LuceeDefinitions
  { ldVersions :: [LuceeVersion],
    ldExtensions :: [Extension],
    ldGeneratedAt :: UTCTime
  }
  deriving stock (Show, Eq, Generic)

-- | Comprehensive error types for pure error handling
data UpdateError
  = -- | HTTP request failures
    HttpError Text
  | -- | HTML/version parsing failures
    ParseError Text
  | -- | nix-prefetch-url failures
    ProcessError Text
  | -- | File operation failures
    FileError Text
  | -- | Nix syntax validation failures
    ValidationError Text
  deriving stock (Show, Eq, Generic)

instance Exception UpdateError

-- | Pure error-handling monad for updates
type UpdateM = ExceptT UpdateError IO

-- | Pure version type parsing
parseVersionType :: Text -> Maybe VersionType
parseVersionType text
  | "-RC" `T.isSuffixOf` text = Just RC
  | "-BETA" `T.isSuffixOf` text = Just Beta
  | T.all (\c -> c /= '-') text = Just Release
  | otherwise = Nothing

-- | Pure version type rendering
renderVersionType :: VersionType -> Text
renderVersionType Release = ""
renderVersionType RC = "-RC"
renderVersionType Beta = "-BETA"

-- | Pure version type checking
isVersionType :: VersionType -> Text -> Bool
isVersionType targetType version =
  parseVersionType version == Just targetType
