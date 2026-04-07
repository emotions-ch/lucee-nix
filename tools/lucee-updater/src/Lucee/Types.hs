{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE OverloadedStrings #-}

module Lucee.Types
  ( LuceeVersion(..)
  , VersionType(..)
  , ArtifactType(..)
  , Extension(..)
  , LuceeDefinitions(..)
  , UpdateError(..)
  , UpdateM
  , parseVersionType
  , renderVersionType
  , isVersionType
  ) where

import Control.Exception (Exception)
import Control.Monad.Except (ExceptT)
import Data.Map.Strict (Map)
import Data.Text (Text)
import qualified Data.Text as T
import Data.Time (UTCTime)
import GHC.Generics (Generic)

-- | Core data types for Lucee artifacts
data LuceeVersion = LuceeVersion
  { lvVersion :: Text                    -- ^ Version string like "7.0.2.106"
  , lvVersionType :: VersionType         -- ^ Release, RC, or Beta
  , lvArtifacts :: Map ArtifactType Text -- ^ Download URLs for different artifacts
  , lvSha256Hashes :: Map ArtifactType Text -- ^ SHA256 hashes for artifacts
  } deriving stock (Show, Eq, Generic)

-- | Version types we track (excludes Snapshots for stability)
data VersionType 
  = Release
  | RC  
  | Beta
  deriving stock (Show, Eq, Ord, Generic, Enum, Bounded)

-- | Different Lucee artifact types
data ArtifactType
  = LuceeZero  -- ^ Minimal Lucee JAR without extensions
  | LuceeJar   -- ^ Full Lucee JAR with bundled extensions
  | LuceeLight -- ^ Lightweight Lucee JAR
  deriving stock (Show, Eq, Ord, Generic, Enum, Bounded)

-- | Extension information
data Extension = Extension
  { extName :: Text                 -- ^ Extension name for Nix identifier
  , extDisplayName :: Text          -- ^ Human-readable extension name  
  , extVersion :: Text              -- ^ Extension version
  , extVersionType :: VersionType   -- ^ Version type (Release, RC, Beta)
  , extDescription :: Text          -- ^ Extension description
  , extDownloadUrl :: Text          -- ^ Download URL for .lex file
  , extUuid :: Text                 -- ^ Unique extension UUID
  , extMinLuceeVersion :: Maybe Text -- ^ Minimum required Lucee version
  , extSha256Hash :: Maybe Text     -- ^ SHA256 hash for verification
  } deriving stock (Show, Eq, Generic)

-- | Complete definitions for Nix generation
data LuceeDefinitions = LuceeDefinitions
  { ldVersions :: [LuceeVersion]
  , ldExtensions :: [Extension]
  , ldGeneratedAt :: UTCTime
  } deriving stock (Show, Eq, Generic)

-- | Comprehensive error types for pure error handling
data UpdateError
  = HttpError Text              -- ^ HTTP request failures
  | ParseError Text             -- ^ HTML/version parsing failures  
  | ProcessError Text           -- ^ nix-prefetch-url failures
  | FileError Text              -- ^ File operation failures
  | ValidationError Text        -- ^ Nix syntax validation failures
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