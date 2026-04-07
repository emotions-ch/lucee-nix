{-# LANGUAGE OverloadedStrings #-}

module Lucee.Validation
  ( -- Character validation
    isValidNixChar
  , isValidBase64Char
  , isValidNixBase32Char
  , isValidIdentifier
  -- Hash validation
  , isValidSha256
  , validateHash
  -- URL validation
  , isValidExtensionUrl
  -- Version validation
  , isValidVersion
  , isNumericPart
  -- Nix syntax validation
  , validateNixSyntax
  , validateBalancedBraces
  , validateStringLiterals
  , validateNixIdentifiers
  , extractIdentifiersFromText
  ) where

import Data.Text (Text)
import qualified Data.Text as T
import Lucee.Types (UpdateError(..))

-- | Character validation functions

-- | Pure Nix character validation
isValidNixChar :: Char -> Bool
isValidNixChar c = 
  (c >= 'a' && c <= 'z') ||
  (c >= 'A' && c <= 'Z') ||
  (c >= '0' && c <= '9') ||
  c `elem` ("-_." :: String)

-- | Pure base64 character validation  
isValidBase64Char :: Char -> Bool
isValidBase64Char c = 
  (c >= 'A' && c <= 'Z') ||
  (c >= 'a' && c <= 'z') ||
  (c >= '0' && c <= '9') ||
  c == '+' || c == '/' || c == '='

-- | Pure Nix base32 hash character validation
isValidNixBase32Char :: Char -> Bool  
isValidNixBase32Char c = 
  c `elem` ("0123456789abcdfghijklmnpqrsvwxyz" :: String)

-- | Pure identifier validation
isValidIdentifier :: Text -> Bool  
isValidIdentifier ident = 
  not (T.null ident) &&
  T.all isValidNixChar ident &&
  not (T.all (\c -> c >= '0' && c <= '9') ident) -- Not pure numeric

-- | Hash validation functions

-- | Pure SHA256 validation (supports both old and new Nix hash formats)
isValidSha256 :: Text -> Bool
isValidSha256 hash 
  | T.length hash == 59 && "sha256-" `T.isPrefixOf` hash =
      -- SRI format: sha256-base64hash (7 char prefix + 52 char hash)
      T.all isValidBase64Char (T.drop 7 hash)
  | T.length hash == 52 = 
      -- Nix base32 format: 52 character base32 hash
      T.all isValidNixBase32Char hash
  | otherwise = False

-- | Pure hash validation for consistency (accepts both base32 and SRI format)
validateHash :: Text -> Either UpdateError Text
validateHash hash 
  | T.length hash == 59 && "sha256-" `T.isPrefixOf` hash =
      if T.length hash == 52 && T.all isValidBase64Char (T.drop 7 hash)
        then Right hash
        else Left $ ValidationError $ "Invalid SRI hash format: " <> hash
  | T.length hash == 52 && T.all isValidNixBase32Char hash = 
      Right hash
  | otherwise = 
      Left $ ValidationError $ "Invalid hash format (expected 52-char base32 or SRI): " <> hash

-- | URL validation functions

-- | Validate extension URL format
isValidExtensionUrl :: Text -> Bool
isValidExtensionUrl url = 
  "https://ext.lucee.org/" `T.isPrefixOf` url &&
  ".lex" `T.isSuffixOf` url &&
  T.length url > 30 -- Reasonable minimum length

-- | Version validation functions

-- | Pure version validation
isValidVersion :: Text -> Bool  
isValidVersion version = 
  let parts = T.splitOn "." version
  in length parts >= 3 && all isNumericPart parts

-- | Pure numeric part validation
isNumericPart :: Text -> Bool
isNumericPart part = not (T.null part) && T.all (\c -> c >= '0' && c <= '9') part

-- | Nix syntax validation functions

-- | Pure Nix syntax validation (basic checks)
validateNixSyntax :: Text -> Either UpdateError ()
validateNixSyntax nixContent = do
  -- Basic structural validation
  validateBalancedBraces nixContent
  validateStringLiterals nixContent
  validateNixIdentifiers nixContent
  return ()

-- | Pure balanced braces validation
validateBalancedBraces :: Text -> Either UpdateError ()
validateBalancedBraces content =
  let braceCount = T.foldl' (\acc c -> 
        case c of
          '{' -> acc + 1
          '}' -> acc - 1
          _ -> acc
        ) 0 content
  in if braceCount == 0 
     then Right ()
     else Left $ ValidationError "Unbalanced braces in Nix expression"

-- | Pure string literal validation
validateStringLiterals :: Text -> Either UpdateError ()
validateStringLiterals content =
  let quoteCount = T.length $ T.filter (== '"') content
  in if even quoteCount
     then Right ()
     else Left $ ValidationError "Unmatched quotes in Nix expression"

-- | Pure identifier validation 
validateNixIdentifiers :: Text -> Either UpdateError ()
validateNixIdentifiers nixContent = 
  let identifiers = extractIdentifiersFromText nixContent
  in if all isValidIdentifier identifiers
     then Right ()
     else Left $ ValidationError "Invalid Nix identifiers found"

-- | Extract identifiers from Nix text for validation
extractIdentifiersFromText :: Text -> [Text]
extractIdentifiersFromText text = 
  T.words $ T.filter (\c -> isValidNixChar c || c == ' ') text