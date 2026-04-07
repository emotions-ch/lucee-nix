{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Control.Monad.Except (runExceptT)
import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.IO as T
import Lucee
import Lucee.Types (ArtifactType (..), LuceeDefinitions (..), LuceeVersion (..), UpdateError (..), VersionType (..), renderVersionType)
import System.Directory (doesFileExist)
import System.Environment (getArgs)
import System.Exit (exitFailure, exitSuccess)
import UnliftIO (liftIO)

-- | Main application entry point
main :: IO ()
main = do
  args <- getArgs

  case args of
    [] -> runFullUpdate
    ["--help"] -> printHelp
    ["--versions-only"] -> runVersionsOnly
    ["--dry-run"] -> runDryRun
    _ -> do
      putStrLn "Invalid arguments. Use --help for usage information."
      exitFailure

-- | Run full update process (semi-automated)
runFullUpdate :: IO ()
runFullUpdate = do
  putStrLn "🔄 Fetching latest Lucee definitions..."

  result <- runExceptT $ updateDefinitions defaultConfig

  case result of
    Left err -> do
      putStrLn $ "❌ Error: " <> show err
      exitFailure
    Right definitions -> do
      putStrLn "✅ Successfully fetched Lucee data"

      -- Generate Nix files
      nixResult <- runExceptT $ generateUpdatedFiles definitions

      case nixResult of
        Left err -> do
          putStrLn $ "❌ Nix generation error: " <> show err
          exitFailure
        Right (luceeNix, extensionsNix) -> do
          putStrLn "📝 Generated Nix definitions"

          -- Write to temporary files for review in current directory
          T.writeFile "lucee-definitions.nix.tmp" luceeNix
          T.writeFile "extensions-definitions.nix.tmp" extensionsNix

          putStrLn ""
          putStrLn "📋 Review the generated files:"
          putStrLn "  lucee-definitions.nix.tmp"
          putStrLn "  extensions-definitions.nix.tmp"
          putStrLn ""
          putStrLn "🔍 Compare with current definitions:"
          putStrLn "  diff lucee/definitions.nix lucee-definitions.nix.tmp"
          putStrLn "  diff extensions/definitions.nix extensions-definitions.nix.tmp"
          putStrLn ""

          -- Interactive confirmation
          putStrLn "Apply changes? [y/N]: "
          response <- getLine

          if response `elem` ["y", "Y", "yes", "Yes"]
            then do
              -- Check if target directories exist
              luceeExists <- doesFileExist "lucee/definitions.nix"
              extensionsExists <- doesFileExist "extensions/definitions.nix"

              if luceeExists && extensionsExists
                then do
                  -- Apply changes
                  T.writeFile "lucee/definitions.nix" luceeNix
                  T.writeFile "extensions/definitions.nix" extensionsNix
                  putStrLn "✅ Updated definition files successfully!"
                  putStrLn ""
                  putStrLn "🧪 Test the changes:"
                  putStrLn "  nix build .#lucee7-zero"
                  exitSuccess
                else do
                  putStrLn "❌ Error: Target directories 'lucee/' or 'extensions/' not found."
                  putStrLn "💡 Please run from the project root directory, or copy files manually:"
                  putStrLn "  cp lucee-definitions.nix.tmp lucee/definitions.nix"
                  putStrLn "  cp extensions-definitions.nix.tmp extensions/definitions.nix"
                  exitFailure
            else do
              putStrLn "❌ Changes not applied."
              exitSuccess

-- | Run versions-only update
runVersionsOnly :: IO ()
runVersionsOnly = do
  putStrLn "🔄 Fetching Lucee versions only..."

  let config = defaultConfig {configIncludeExtensions = False}
  result <- runExceptT $ updateLuceeVersions config

  case result of
    Left err -> do
      putStrLn $ "❌ Error: " <> show err
      exitFailure
    Right versions -> do
      putStrLn $ "✅ Found " <> show (length versions) <> " versions:"
      mapM_ printVersionInfo versions
      exitSuccess

-- | Run dry-run mode (no file changes)
runDryRun :: IO ()
runDryRun = do
  putStrLn "🔍 Dry run mode - no files will be modified"

  result <- runExceptT $ updateDefinitions defaultConfig

  case result of
    Left err -> do
      putStrLn $ "❌ Error: " <> show err
      exitFailure
    Right definitions -> do
      nixResult <- runExceptT $ generateUpdatedFiles definitions

      case nixResult of
        Left err -> do
          putStrLn $ "❌ Generation error: " <> show err
          exitFailure
        Right (luceeNix, extensionsNix) -> do
          putStrLn "✅ Generated definitions successfully"
          putStrLn ""
          putStrLn "📊 Summary:"
          putStrLn $ "  Lucee versions: " <> show (length $ ldVersions definitions)
          putStrLn $ "  Extensions: " <> show (length $ ldExtensions definitions)
          putStrLn $ "  Nix expressions: " <> show (T.length luceeNix + T.length extensionsNix) <> " chars"
          putStrLn ""
          putStrLn "🔍 Generated lucee/definitions.nix:"
          T.putStrLn luceeNix
          putStrLn ""
          putStrLn "🔍 Generated extensions/definitions.nix (first 5 lines):"
          T.putStrLn $ T.unlines $ take 5 $ T.lines extensionsNix
          exitSuccess

-- | Print version information
printVersionInfo :: LuceeVersion -> IO ()
printVersionInfo version = do
  let versionStr = lvVersion version <> renderVersionType (lvVersionType version)
      typeStr = show (lvVersionType version)
      artifactCount = show $ length $ lvArtifacts version
  putStrLn $ "  📦 " <> T.unpack versionStr <> " (" <> typeStr <> ") - " <> artifactCount <> " artifacts"

-- | Print help information
printHelp :: IO ()
printHelp = do
  putStrLn "Lucee Definitions Updater"
  putStrLn ""
  putStrLn "Usage:"
  putStrLn "  lucee-updater                  Run full semi-automated update"
  putStrLn "  lucee-updater --versions-only  Show available versions only"
  putStrLn "  lucee-updater --dry-run        Preview changes without applying"
  putStrLn "  lucee-updater --help          Show this help"
  putStrLn ""
  putStrLn "The tool maintains functional purity by:"
  putStrLn "  - Using pure functions for all parsing and generation"
  putStrLn "  - Clear separation of IO boundaries"
  putStrLn "  - Comprehensive error handling with ExceptT"
  putStrLn "  - Semi-automated workflow for user review"
