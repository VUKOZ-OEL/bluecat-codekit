#!/bin/bash

export DATA=$1 # First argument is the input file (e.g., cloud_name) without extension
export DATADIR=$2 # Second argument is the dir path (e.g., /storage/plzen1/home/krucek/gs-lcr/001)

VOXELIZE=${1:-false}
VOXEL_RES=${1:-0.02}
ADD_TIME=${1:-false}

export LOG_FILE="$DATADIR/$DATA.info.txt"
export SOURCE_DATA="${DATA}.laz"

#create log file
echo "$(date) job started" >> $LOG_FILE
echo "$PBS_JOBID is running on node `hostname -f`" >> $LOG_FILE
test -n "$SCRATCHDIR" && echo "scratch dir: $SCRATCHDIR" >> $LOG_FILE # || { echo >&2 "Variable SCRATCHDIR is not set!"}

# move into scratch directory
cd $SCRATCHDIR && echo "move to SCRATCHDIR ok" >> $LOG_FILE # || echo "error: cd $SCRATCHDIR" >> $LOG_FILE

#load modules
module add singul/ && echo "singularity loaded" >> $LOG_FILE # || echo "singularity not loaded" >> $LOG_FILE
module add git/ && echo "git loaded" >> $LOG_FILE || echo "git not loaded" >> $LOG_FILE

# get processing scripts from github
git clone https://github.com/VUKOZ-OEL/bluecat-codekit
cp bluecat-codekit/cesnet/rayprocess/*.sh $SCRATCHDIR

source setup_scratch.sh && echo "setup_scratch ok" >> $LOG_FILE # || { echo "Error on setup_scratch" >> $LOG_FILE}
source create_pdal_pipeline.sh $SOURCE_DATA cloud.laz $VOXELIZE $ADD_TIME $VOXEL_RES

source process_data.sh 
source cleanup_scratch.sh