{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QuasiQuotes #-}

module Lucee.Nix
  ( generateDefinitions,
    generateVersionDefinition,
    generateExtensionDefinition,
    renderNixFile,
    nixFileHeader,
    nixExtensionsFileHeader,
    nixFileFooter,
  )
where

import Control.Monad (unless)
import Control.Monad.Except (throwError)
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as M
import Data.Text (Text)
import qualified Data.Text as T
import Data.Time (UTCTime, defaultTimeLocale, formatTime)
import Lucee.Constants
import Lucee.Types
import Lucee.Validation (isValidNixChar, makeExtensionNixId, makeVersionNixId, validateNixSyntax)

-- | Pure function to generate Lucee version definitions only
generateDefinitions :: LuceeDefinitions -> Either UpdateError Text
generateDefinitions defs = do
  versionDefs <- traverse generateVersionDefinition (ldVersions defs)

  let header = nixFileHeader (ldGeneratedAt defs)
      versions = T.unlines versionDefs
      footer = nixFileFooter

  pure $ T.unlines [header, "", versions, "", footer]

-- | Pure version definition generation
generateVersionDefinition :: LuceeVersion -> Either UpdateError Text
generateVersionDefinition version = do
  -- Generate definitions for all available artifacts
  let artifacts = M.toList $ lvSha256Hashes version
  artifactDefs <- traverse (generateArtifactDefinition version) artifacts
  pure $ T.unlines artifactDefs

-- | Generate definition for a specific artifact type
generateArtifactDefinition :: LuceeVersion -> (ArtifactType, Text) -> Either UpdateError Text
generateArtifactDefinition version (artifactType, hash) = do
  let nixId = makeVersionNixId (lvVersion version) (lvVersionType version) artifactType
      versionStr = lvVersion version <> renderVersionType (lvVersionType version)
      artifactName = renderArtifactName artifactType
      description = renderArtifactDescription artifactType

  Right $
    T.unlines
      [ "  " <> nixId <> " = mkLuceeVersion {",
        "    name = \"" <> artifactName <> "\";",
        "    description = \"" <> description <> "\";",
        "    version = \"" <> versionStr <> "\";",
        "    sha256 = \"" <> hash <> "\";",
        "    javaVersion = " <> T.pack (show defaultJavaVersion) <> ";",
        "  };"
      ]

-- | Render artifact name for Nix
renderArtifactName :: ArtifactType -> Text
renderArtifactName LuceeZero = "lucee-zero"
renderArtifactName LuceeLight = "lucee-light"
renderArtifactName LuceeJar = "lucee"

-- | Render artifact description
renderArtifactDescription :: ArtifactType -> Text
renderArtifactDescription LuceeZero = "Lucee Jar file without any Extensions bundled or doc and admin bundles, \\\"Lucee zero\\\""
renderArtifactDescription LuceeLight = "Lucee Jar file without any Extensions bundled, \\\"Lucee light\\\""
renderArtifactDescription LuceeJar = "Lucee jar file without dependencies Lucee needs to run"

-- | Use hash as-is (base32 format from nix-prefetch-url)
-- convertToSRIHash :: Text -> Text  -- Removed since we use base32 directly

-- | Pure extension definition generation
generateExtensionDefinition :: Extension -> Either UpdateError Text
generateExtensionDefinition ext = do
  case extSha256Hash ext of
    Nothing -> Right "" -- Skip extensions without valid hashes
    Just sha256Hash -> do
      let nixId = makeExtensionNixId (extName ext)

      Right $
        T.unlines
          [ "  " <> nixId <> " = mkLuceeExtension {",
            "    name = \"" <> extDisplayName ext <> "\";",
            "    description = \"" <> escapeNixString (extDescription ext) <> "\";",
            "    version = \"" <> extVersion ext <> "\";",
            "    sha256 = \"" <> sha256Hash <> "\";",
            "  };",
            ""
          ]

-- | Pure Nix file rendering with proper structure
renderNixFile :: Text -> Text -> Text -> Text
renderNixFile header content footer =
  T.unlines [header, "", content, "", footer]

-- | Pure Nix file header generation
nixFileHeader :: UTCTime -> Text
nixFileHeader timestamp =
  T.unlines
    [ "# Lucee Definitions - Auto-generated",
      "# Generated at: " <> T.pack (formatTime defaultTimeLocale "%Y-%m-%d %H:%M:%S UTC" timestamp),
      "# DO NOT EDIT MANUALLY - Use lucee-updater tool",
      "",
      "{",
      "  mkLuceeVersion,",
      "  mkLuceeWithTomcat11,",
      "  mkLuceeWithTomcat10,",
      "  mkLuceeWithTomcat9,",
      "}:",
      "",
      "{"
    ]

-- | Pure Nix file header generation for extensions
nixExtensionsFileHeader :: UTCTime -> Text
nixExtensionsFileHeader timestamp =
  T.unlines
    [ "# Lucee Extensions Definitions - Auto-generated",
      "# Generated at: " <> T.pack (formatTime defaultTimeLocale "%Y-%m-%d %H:%M:%S UTC" timestamp),
      "# DO NOT EDIT MANUALLY - Use lucee-updater tool",
      "",
      "{ mkLuceeExtension }:",
      "",
      "{"
    ]

-- | Pure Nix file footer
nixFileFooter :: Text
nixFileFooter = "}"

-- | Pure string escaping for Nix
escapeNixString :: Text -> Text
escapeNixString = T.concatMap escapeChar
  where
    escapeChar '"' = "\\\""
    escapeChar '\\' = "\\\\"
    escapeChar '\n' = "\\n"
    escapeChar '\t' = "\\t"
    escapeChar c = T.singleton c
