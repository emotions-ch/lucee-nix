{-# LANGUAGE OverloadedStrings #-}

module Lucee.Constants
  ( -- URLs
    luceeDownloadBaseUrl
  , luceeCdnBaseUrl
  , luceeExtensionBaseUrl
  , lexUrlPattern
  
  -- File Extensions
  , lexExtension
  , jarExtension
  
  -- Default Values
  , defaultVersion
  , defaultJavaVersion
  , defaultExtensionDescription
  , maxDescriptionLength
  
  -- Version Processing
  , versionPrefixesToRemove
  , versionSuffixesToRemove
  , versionKeywords
  
  -- Hash Constants
  , nixBase32Chars
  , sriHashPrefix
  , sriHashLength
  , sriPrefixLength
  , base32HashLength
  , base64HashLength
  
  -- String Processing
  , lexExtensionLength
  , extensionSuffixLength
  , errorMessageTruncateLength
  , minUrlLength
  
  -- Error Messages
  , ErrorMessages(..)
  , errorMessages
  
  -- Process Commands
  , nixPrefetchUrlCmd
  , nixHashArgs
  ) where

import Data.Text (Text)

-- | URLs and patterns
luceeDownloadBaseUrl :: Text
luceeDownloadBaseUrl = "https://download.lucee.org/"

luceeCdnBaseUrl :: Text  
luceeCdnBaseUrl = "https://cdn.lucee.org/"

luceeExtensionBaseUrl :: Text
luceeExtensionBaseUrl = "https://ext.lucee.org/"

lexUrlPattern :: String
lexUrlPattern = "https://ext\\.lucee\\.org/[^\"]*\\.lex"

-- | File extensions
lexExtension :: Text
lexExtension = ".lex"

jarExtension :: Text  
jarExtension = ".jar"

-- | Default values
defaultVersion :: Text
defaultVersion = "1.0.0"

defaultJavaVersion :: Int
defaultJavaVersion = 25

defaultExtensionDescription :: Text
defaultExtensionDescription = "Lucee Extension"

maxDescriptionLength :: Int
maxDescriptionLength = 200

-- | Version processing constants
versionPrefixesToRemove :: [Text]
versionPrefixesToRemove = ["extension-", "jdbc-", "light-", "zero-"]

versionSuffixesToRemove :: [Text]
versionSuffixesToRemove = ["-rc", "-beta", "-snapshot", "-alpha", ".jre8", ".jdk8", ".jdbc4", "ojdbc11", ".0001l"]

versionKeywords :: [Text]
versionKeywords = ["snapshot", "beta", "rc", "alpha", "jre8", "jdk8", "ojdbc11", "jdbc4", "0001l"]

-- | Hash format constants
nixBase32Chars :: String
nixBase32Chars = "0123456789abcdfghijklmnpqrsvwxyz"

sriHashPrefix :: Text
sriHashPrefix = "sha256-"

sriHashLength :: Int
sriHashLength = 59

sriPrefixLength :: Int
sriPrefixLength = 7

base32HashLength :: Int
base32HashLength = 52

base64HashLength :: Int
base64HashLength = 52

-- | String processing constants
lexExtensionLength :: Int
lexExtensionLength = 4  -- Length of ".lex"

extensionSuffixLength :: Int
extensionSuffixLength = 10  -- Length of ".extension" or "-extension"

errorMessageTruncateLength :: Int
errorMessageTruncateLength = 50

minUrlLength :: Int
minUrlLength = 30

-- | Error message templates
data ErrorMessages = ErrorMessages
  { emptyResponse :: Text
  , fetchFailed :: Text
  , maxRetriesExceeded :: Text  
  , failedAfterRetries :: Text
  , invalidSriHash :: Text
  , invalidHashFormat :: Text
  , unbalancedBraces :: Text
  , unmatchedQuotes :: Text
  , invalidNixIdentifiers :: Text
  , nixPrefetchFailed :: Text
  , invalidSha256Hash :: Text
  } deriving (Show)

errorMessages :: ErrorMessages
errorMessages = ErrorMessages
  { emptyResponse = "Empty response from download page"
  , fetchFailed = "Failed to fetch "
  , maxRetriesExceeded = "Max retries exceeded for "
  , failedAfterRetries = "Failed after retries for "
  , invalidSriHash = "Invalid SRI hash format: "
  , invalidHashFormat = "Invalid hash format (expected 52-char base32 or SRI): "
  , unbalancedBraces = "Unbalanced braces in Nix expression"
  , unmatchedQuotes = "Unmatched quotes in Nix expression"
  , invalidNixIdentifiers = "Invalid Nix identifiers found"
  , nixPrefetchFailed = "nix-prefetch-url failed for "
  , invalidSha256Hash = "Invalid SHA256 hash for "
  }

-- | Process command constants
nixPrefetchUrlCmd :: String
nixPrefetchUrlCmd = "nix-prefetch-url"

nixHashArgs :: [String]
nixHashArgs = ["hash", "to-sri", "--type", "sha256"]