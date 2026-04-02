{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QuasiQuotes #-}

module Lucee.Nix
  ( generateDefinitions
  , generateVersionDefinition  
  , generateExtensionDefinition
  , renderNixFile
  , validateNixSyntax
  , nixFileHeader
  , nixFileFooter
  ) where

import Control.Monad.Except (throwError)
import Control.Monad (unless)
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as M
import Data.Text (Text)
import qualified Data.Text as T
import Data.Time (UTCTime, formatTime, defaultTimeLocale)

import Lucee.Types

-- | Pure function to generate complete Nix definitions
generateDefinitions :: LuceeDefinitions -> Either UpdateError Text  
generateDefinitions defs = do
  versionDefs <- traverse generateVersionDefinition (ldVersions defs)
  extensionDefs <- traverse generateExtensionDefinition (ldExtensions defs)
  
  let header = nixFileHeader (ldGeneratedAt defs)
      versions = T.unlines versionDefs
      extensions = T.unlines extensionDefs  
      footer = nixFileFooter
      
  pure $ T.unlines [header, "", versions, "", extensions, "", footer]

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
      
  Right $ T.unlines
    [ "  " <> nixId <> " = mkLuceeVersion {"
    , "    name = \"" <> artifactName <> "\";"  
    , "    description = \"" <> description <> "\";"
    , "    version = \"" <> versionStr <> "\";"
    , "    sha256 = \"" <> hash <> "\";"
    , "    javaVersion = 25;"
    , "  };"
    ]

-- | Pure Nix identifier generation for versions with artifacts
makeVersionNixId :: Text -> VersionType -> ArtifactType -> Text
makeVersionNixId version vtype artifactType = 
  let versionPart = sanitizeVersion version vtype
      artifactSuffix = case artifactType of
        LuceeZero -> "-zero"
        LuceeLight -> "-light" 
        LuceeJar -> ""
  in versionPart <> artifactSuffix

-- | Sanitize version for Nix identifier  
sanitizeVersion :: Text -> VersionType -> Text
sanitizeVersion version vtype = 
  let majorVersion = T.take 1 version  -- e.g. "7" from "7.0.2.106"
      minorVersion = T.take 1 (T.drop 2 version) -- e.g. "0" from "7.0.2.106"  
  in case vtype of
       Release -> "lucee" <> majorVersion
       RC -> "lucee" <> majorVersion <> "_" <> minorVersion <> "-RC" 
       Beta -> "lucee" <> majorVersion <> "_" <> minorVersion <> "-BETA"

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
  sha256Hash <- case extSha256Hash ext of
    Just hash -> Right hash
    Nothing -> Left $ ValidationError $ "Missing SHA256 hash for extension " <> extName ext
    
  let nixId = makeExtensionNixId (extName ext)
      
  Right $ T.unlines  
    [ "  " <> nixId <> " = mkLuceeExtension {"
    , "    name = \"" <> extName ext <> "\";"
    , "    description = \"" <> escapeNixString (extDescription ext) <> "\";"
    , "    version = \"" <> extVersion ext <> "\";" 
    , "    sha256 = \"" <> sha256Hash <> "\";"
    , "  };"
    ]

-- | Pure Nix file rendering with proper structure
renderNixFile :: Text -> Text -> Text -> Text
renderNixFile header content footer = 
  T.unlines [header, "", content, "", footer]

-- | Pure Nix syntax validation (basic checks)
validateNixSyntax :: Text -> Either UpdateError ()
validateNixSyntax nixContent = do
  -- Basic structural validation
  unless (hasBalancedBraces nixContent) $ 
    throwError $ ValidationError "Unbalanced braces in Nix expression"
    
  unless (hasValidStrings nixContent) $
    throwError $ ValidationError "Invalid string literals in Nix expression"
    
  unless (hasValidIdentifiers nixContent) $
    throwError $ ValidationError "Invalid Nix identifiers"
    
  pure ()

-- | Pure Nix file header generation
nixFileHeader :: UTCTime -> Text
nixFileHeader timestamp = T.unlines
  [ "# Lucee Definitions - Auto-generated"
  , "# Generated at: " <> T.pack (formatTime defaultTimeLocale "%Y-%m-%d %H:%M:%S UTC" timestamp)
  , "# DO NOT EDIT MANUALLY - Use lucee-updater tool"
  , ""
  , "{"
  , "  mkLuceeVersion,"
  , "  mkLuceeWithTomcat11,"
  , "  mkLuceeWithTomcat10," 
  , "  mkLuceeWithTomcat9,"
  , "}:"
  , ""
  , "{"
  ]

-- | Pure Nix file footer
nixFileFooter :: Text
nixFileFooter = "}"

-- | Pure extension Nix identifier generation
makeExtensionNixId :: Text -> Text
makeExtensionNixId name = 
  let sanitized = T.map sanitizeChar name
  in if T.all isValidNixChar sanitized 
     then sanitized
     else "\"" <> sanitized <> "\""

-- | Pure character sanitization for Nix identifiers
sanitizeChar :: Char -> Char
sanitizeChar c
  | isValidNixChar c = c
  | c == '-' = '_'
  | c == '.' = '_'  
  | otherwise = '_'

-- | Pure Nix character validation
isValidNixChar :: Char -> Bool
isValidNixChar c = 
  (c >= 'a' && c <= 'z') || 
  (c >= 'A' && c <= 'Z') || 
  (c >= '0' && c <= '9') || 
  c == '_'

-- | Pure string escaping for Nix
escapeNixString :: Text -> Text
escapeNixString = T.concatMap escapeChar
  where
    escapeChar '"' = "\\\""
    escapeChar '\\' = "\\\\"
    escapeChar '\n' = "\\n"
    escapeChar '\t' = "\\t"  
    escapeChar c = T.singleton c

-- | Pure balanced braces validation
hasBalancedBraces :: Text -> Bool
hasBalancedBraces text = checkBalance 0 (T.unpack text)
  where
    checkBalance :: Int -> String -> Bool
    checkBalance 0 [] = True
    checkBalance n [] = n == 0
    checkBalance n ('{':cs) = checkBalance (n + 1) cs
    checkBalance n ('}':cs) = n > 0 && checkBalance (n - 1) cs
    checkBalance n (_:cs) = checkBalance n cs

-- | Pure string literal validation
hasValidStrings :: Text -> Bool  
hasValidStrings text = checkStrings False (T.unpack text)
  where
    checkStrings :: Bool -> String -> Bool
    checkStrings False [] = True
    checkStrings True [] = False -- Unclosed string
    checkStrings inString ('"':cs) = checkStrings (not inString) cs
    checkStrings inString ('\\':_:cs) = checkStrings inString cs -- Escaped char
    checkStrings inString (_:cs) = checkStrings inString cs

-- | Pure identifier validation 
hasValidIdentifiers :: Text -> Bool
hasValidIdentifiers text = 
  let identifiers = extractIdentifiers text
  in all isValidIdentifier identifiers

-- | Pure identifier extraction (simplified)
extractIdentifiers :: Text -> [Text]
extractIdentifiers text = 
  T.words $ T.filter (\c -> isValidNixChar c || c == ' ') text

-- | Pure identifier validation
isValidIdentifier :: Text -> Bool  
isValidIdentifier ident = 
  not (T.null ident) && 
  T.all isValidNixChar ident &&
  not (T.head ident >= '0' && T.head ident <= '9') -- Can't start with digit