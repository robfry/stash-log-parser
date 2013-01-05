#!/bin/bash

set -e
set -x
set -u

rm -f *.png


# Ensure that 'logparser' is in the PATH (e.g. run rebuild.sh or 'cabal copy')
DATE=${1:-`date "+%Y-%m"`}
LOG_FILE=${2:-"../access-logs/atlassian-stash-access-${DATE}*"}

time logparser gitOperations ${LOG_FILE} +RTS -sstderr > plot-git-ops
gnuplot < gnuplot/generate-git-ops-plot.plot

time logparser gitDurations ${LOG_FILE} +RTS -sstderr > clone-duration
gnuplot < gnuplot/generate-git-durations.plot

time logparser maxConn ${LOG_FILE} +RTS -sstderr > plot-all
gnuplot < gnuplot/generate-max-conn-plot.plot

time logparser protocolStats ${LOG_FILE} > protocol-stats
gnuplot < gnuplot/generate-git-protocol.plot
