{-# LANGUAGE OverloadedStrings, BangPatterns #-}

module Stash.Log.Output
( generateProtocolData
, generateCloneRequestDurations
, generatePlotDataConcurrentConn
, generatePlotDataGitOps
, parseAndPrint
, printCountLines
) where


import qualified Data.ByteString.Lazy.Char8 as L
import qualified Data.ByteString.Char8 as S
import qualified Data.Map as M
import Control.Monad (liftM)
import Stash.Log.Parser
import Stash.Log.Analyser
import Stash.Log.GitOpsAnalyser
import Stash.Log.File
import Text.Printf (printf)
import Data.Aeson


readConfig :: String -> IO (Maybe String)
readConfig key = do
        json <- L.readFile "logparser.state"
        return $ (decode json :: Maybe (M.Map String String)) >>= M.lookup key

readLogFiles :: String -> [FilePath] -> IO [L.ByteString]
readLogFiles key path = do
        date <- readConfig key
        toLines (createPredicate date) path
        where createPredicate maybeDate = maybe (\_ -> True) (\date -> (\file -> True)) maybeDate


generateProtocolData :: (Input -> [ProtocolStats]) -> [FilePath] -> IO ()
generateProtocolData f path = do
        plotData <- liftM f $ readLogFiles "generateProtocolData" path
        printf "# Date | SSH | HTTP(s)\n"
        mapM_ (\(ProtocolStats date ssh http) -> printf "%s|%d|%d\n" date ssh http) plotData

generatePlotDataGitOps :: (Input -> [GitOperationStats]) -> [FilePath] -> IO ()
generatePlotDataGitOps f path = do
        plotData <- liftM f $ readLogFiles "generatePlotDataGitOps" path
        printf "# Date | clone | fetch | shallow clone | push | ref advertisement | clone (hit) | fetch (hit) | shallow clone (hit) | push (hit) | ref advertisement (hit) | clone (miss) | fetch (miss) | shallow clone (miss) | push (miss) | ref advertisement (miss)\n"
        mapM_ (\(GitOperationStats date [a,b,c,d,e] [aHit,bHit,cHit,dHit,eHit])
                -> printf "%s|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d\n" date (a+aHit) (b+bHit) (c+cHit) (d+dHit) (e+eHit) aHit bHit cHit dHit eHit a b c d e) plotData

generatePlotDataConcurrentConn :: (Input -> [DateValuePair]) -> [FilePath] -> IO ()
generatePlotDataConcurrentConn f path = do
        plotData <- liftM f $ readLogFiles "generatePlotDataConcurrentConn" path
        printf "# Date | Max concurrent connection\n"
        mapM_ (\pd -> printf "%s|%d\n" (formatLogDate $ getLogDate pd) (getValue pd)) plotData

generateCloneRequestDurations :: (Input -> [RequestDurationStat]) -> [FilePath] -> IO ()
generateCloneRequestDurations g path = do
        plotData <- liftM g $ readLogFiles "generateCloneRequestDurations" path
        printf "# Date | Clone duration (cache hit) | Clone duration (cache miss) | Fetch (hit) | Fetch (miss) | Shallow Clone (hit) | Shallow Clone (miss) | Push (hit) | Push (miss) | Ref adv (hit) | Ref adv (miss) | Client IP | Username \n"
        mapM_ (\(RequestDurationStat date clientIp [cm,fm,sm,pm,rm] [c,f,s,p,r] username)
                -> printf "%s|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%s|%s\n" (show date) c cm f fm s sm p pm r rm clientIp (S.unpack username)) plotData

parseAndPrint :: (Show a) => (Input -> a) -> [FilePath] -> IO ()
parseAndPrint f path = print . f . L.lines =<< readFiles (\x -> True) path

printCountLines :: (Show a) => (L.ByteString -> a) -> [FilePath] -> IO ()
printCountLines f path = print . f =<< readFiles (\x -> True) path

formatLogDate :: LogDate -> String
formatLogDate date = printf "%04d-%02d-%02d %02d:%02d" (getYear date) (getMonth date)
                            (getDay date) (getHour date) (getMinute date)
