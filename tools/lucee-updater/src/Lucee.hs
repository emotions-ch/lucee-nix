{-# LANGUAGE OverloadedStrings #-}

module Lucee
  ( updateDefinitions
  , updateLuceeVersions
  , updateExtensions  
  , generateUpdatedFiles
  , LuceeConfig(..)
  , defaultConfig
  ) where

import Control.Monad.Except (runExceptT, throwError, liftIO)
import Data.Time (getCurrentTime)
import Data.Text (Text)
import qualified Data.Text as T

import Lucee.Types
import Lucee.Fetch (fetchDownloadPage)
import Lucee.Parse (parseVersions, parseExtensions)
import Lucee.Hash (computeHashesForVersion)
import Lucee.Nix (generateDefinitions)

-- | Configuration for the update process
data LuceeConfig = LuceeConfig
  { configTrackReleases :: Bool
  , configTrackRCs :: Bool
  , configTrackBetas :: Bool
  , configBaseUrl :: Text
  , configIncludeExtensions :: Bool
  } deriving (Show, Eq)

-- | Default configuration matching user requirements
defaultConfig :: LuceeConfig  
defaultConfig = LuceeConfig
  { configTrackReleases = True
  , configTrackRCs = True
  , configTrackBetas = True
  , configBaseUrl = "https://download.lucee.org/"
  , configIncludeExtensions = True
  }

-- | Main orchestration function with pure functional pipeline
updateDefinitions :: LuceeConfig -> UpdateM LuceeDefinitions
updateDefinitions config = do
  -- Pure functional pipeline with clear IO boundaries
  html <- fetchDownloadPage (configBaseUrl config)
  
  -- Pure parsing  
  allVersions <- case parseVersions html of
    Left err -> throwError err
    Right versions -> pure versions
    
  -- Pure filtering based on configuration
  let filteredVersions = filterVersionsByConfig config allVersions
  
  -- IO boundary: compute hashes in parallel  
  versionsWithHashes <- traverse computeHashesForVersion filteredVersions
  
  -- Handle extensions if configured
  extensions <- if configIncludeExtensions config
    then updateExtensions html
    else pure []
    
  -- Generate timestamp
  timestamp <- liftIO getCurrentTime
  
  pure $ LuceeDefinitions versionsWithHashes extensions timestamp

-- | Update Lucee versions with pure functional approach
updateLuceeVersions :: LuceeConfig -> UpdateM [LuceeVersion]  
updateLuceeVersions config = do
  html <- fetchDownloadPage (configBaseUrl config)
  
  allVersions <- case parseVersions html of
    Left err -> throwError err
    Right versions -> pure versions
    
  let filteredVersions = filterVersionsByConfig config allVersions
  traverse computeHashesForVersion filteredVersions

-- | Update extensions with functional pipeline
updateExtensions :: Text -> UpdateM [Extension]
updateExtensions html = do  
  extensions <- case parseExtensions html of
    Left err -> throwError err
    Right exts -> pure exts
    
  -- For now, return basic extensions
  -- In full implementation, would compute hashes for each
  pure $ take 20 extensions -- Limit for initial implementation

-- | Generate updated definition files  
generateUpdatedFiles :: LuceeDefinitions -> UpdateM (Text, Text)
generateUpdatedFiles defs = do
  -- Generate Lucee definitions
  luceeNix <- case generateDefinitions defs of
    Left err -> throwError err
    Right nix -> pure nix
    
  -- Generate extension definitions (placeholder)
  let extensionsNix = generateExtensionsNix (ldExtensions defs)
  
  pure (luceeNix, extensionsNix)

-- | Pure version filtering based on configuration
filterVersionsByConfig :: LuceeConfig -> [LuceeVersion] -> [LuceeVersion]
filterVersionsByConfig config = filter (shouldIncludeVersion config)

-- | Pure predicate for version inclusion
shouldIncludeVersion :: LuceeConfig -> LuceeVersion -> Bool  
shouldIncludeVersion config version =
  case lvVersionType version of
    Release -> configTrackReleases config
    RC -> configTrackRCs config  
    Beta -> configTrackBetas config

-- | Pure extension definitions generation (placeholder)
generateExtensionsNix :: [Extension] -> Text
generateExtensionsNix extensions = T.unlines
  [ "{ mkLuceeExtension }:"
  , ""
  , "{"
  , T.unlines $ map renderExtensionPlaceholder extensions
  , "}"
  ]

-- | Pure extension placeholder rendering
renderExtensionPlaceholder :: Extension -> Text
renderExtensionPlaceholder ext = T.unlines
  [ "  " <> sanitizeName (extName ext) <> " = mkLuceeExtension {"
  , "    name = \"" <> extName ext <> "\";"
  , "    version = \"" <> extVersion ext <> "\";"  
  , "    description = \"" <> T.take 100 (extDescription ext) <> "\";"
  , "    # sha256 = \"...\"; # TODO: Compute hash"
  , "  };"
  ]

-- | Pure name sanitization
sanitizeName :: Text -> Text  
sanitizeName = T.map (\c -> if c == '-' || c == '.' then '_' else c)