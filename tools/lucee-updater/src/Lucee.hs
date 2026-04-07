{-# LANGUAGE OverloadedStrings #-}

module Lucee
  ( updateDefinitions
  , updateLuceeVersions
  , updateExtensions  
  , generateUpdatedFiles
  , LuceeConfig(..)
  , defaultConfig
  ) where

import Control.Concurrent.Async (mapConcurrently)
import Control.Monad.Except (throwError, runExceptT)
import Control.Monad.IO.Class (liftIO)
import Data.Time (getCurrentTime)
import Data.Text (Text)
import qualified Data.Text as T

import Lucee.Types
import Lucee.Fetch (fetchDownloadPage)
import Lucee.Parse (parseVersions, parseExtensions)
import Lucee.Hash (computeHashesForVersion, computeHashesForExtensions)
import Lucee.Nix (generateDefinitions, generateExtensionDefinition, nixFileFooter)

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
  
  -- IO boundary: compute hashes for multiple versions in parallel
  versionResults <- liftIO $ mapConcurrently (\version -> 
    runExceptT (computeHashesForVersion version)) filteredVersions
  
  -- Check for any errors in parallel processing
  versionsWithHashes <- case sequence versionResults of
    Left err -> throwError err
    Right versions -> pure versions
  
  -- Handle extensions if configured
  extensions <- if configIncludeExtensions config
    then updateExtensions html
    else pure []
    
  -- Generate timestamp
  timestamp <- liftIO getCurrentTime
  
  pure $ LuceeDefinitions versionsWithHashes extensions timestamp

-- | Update Lucee versions with pure functional approach (no hash computation)
updateLuceeVersions :: LuceeConfig -> UpdateM [LuceeVersion]  
updateLuceeVersions config = do
  html <- fetchDownloadPage (configBaseUrl config)
  
  allVersions <- case parseVersions html of
    Left err -> throwError err
    Right versions -> pure versions
    
  let filteredVersions = filterVersionsByConfig config allVersions
  pure filteredVersions -- Return without computing hashes

-- | Update extensions with functional pipeline
updateExtensions :: Text -> UpdateM [Extension]
updateExtensions html = do  
  extensions <- case parseExtensions html of
    Left err -> throwError err
    Right exts -> pure exts
    
  -- Compute hashes for extensions
  extensionsWithHashes <- computeHashesForExtensions extensions
  
  pure extensionsWithHashes

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

-- | Generate extension definitions using proper Lucee.Nix logic
generateExtensionsNix :: [Extension] -> Text
generateExtensionsNix extensions = 
  case traverse generateExtensionDefinition extensions of
    Left err -> T.unlines
      [ "{ mkLuceeExtension }:"
      , ""
      , "{"
      , "  # Error generating extensions: " <> T.pack (show err)
      , "}"
      ]
    Right extensionDefs -> 
      let nonEmptyDefs = filter (not . T.null . T.strip) extensionDefs
      in T.unlines
        [ "{ mkLuceeExtension }:"
        , ""
        , "{"
        , T.unlines nonEmptyDefs
        , nixFileFooter
        ]