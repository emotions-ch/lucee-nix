{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE FlexibleContexts #-}

module Lucee.Fetch
  ( fetchDownloadPage
  , fetchUrl
  , fetchWithRetry
  ) where

import Control.Exception (try)
import Control.Monad.Except (ExceptT(..), throwError)
import Control.Monad.IO.Class (liftIO)
import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.Encoding as T
import Network.HTTP.Req
  ( GET(GET), NoReqBody(..), bsResponse, defaultHttpConfig, https
  , req, responseBody, runReq, useHttpsURI, HttpException
  )
import Text.URI (URI, mkURI)

import Lucee.Types

-- | Fetch the main Lucee download page (IO boundary)
fetchDownloadPage :: Text -> UpdateM Text
fetchDownloadPage baseUrl = do
  html <- fetchUrl baseUrl
  if T.null html
    then throwError $ HttpError "Empty response from download page"
    else pure html

-- | Generic URL fetching with error handling (IO boundary)  
fetchUrl :: Text -> UpdateM Text
fetchUrl urlText = do
  result <- liftIO $ try @HttpException $ runReq defaultHttpConfig $ do
    uri <- case mkURI urlText of
      Left _ -> error "Invalid URL"
      Right u -> pure u
    case useHttpsURI uri of
      Nothing -> error "Not an HTTPS URL"
      Just (url', options) -> do
        response <- req GET url' NoReqBody bsResponse options
        pure $ T.decodeUtf8 $ responseBody response
  
  case result of
    Left ex -> throwError $ HttpError $ "Failed to fetch " <> urlText <> ": " <> T.pack (show ex)
    Right content -> pure content

-- | Fetch with retry logic for network reliability (IO boundary)
fetchWithRetry :: Int -> Text -> UpdateM Text  
fetchWithRetry maxRetries urlText = go maxRetries
  where
    go 0 = throwError $ HttpError $ "Max retries exceeded for " <> urlText
    go n = do
      result <- liftIO $ try @HttpException $ runReq defaultHttpConfig $ do
        uri <- case mkURI urlText of
          Left _ -> error "Invalid URL"
          Right u -> pure u
        case useHttpsURI uri of
          Nothing -> error "Not an HTTPS URL"
          Just (url', options) -> do
            response <- req GET url' NoReqBody bsResponse options
            pure $ T.decodeUtf8 $ responseBody response
      
      case result of
        Left ex -> 
          if n > 1 
            then do
              liftIO $ putStrLn $ "Retry " <> show (maxRetries - n + 1) <> " for " <> T.unpack urlText
              go (n - 1)
            else throwError $ HttpError $ "Failed after retries: " <> T.pack (show ex)
        Right content -> pure content