#!/bin/bash

# set variables, PATH INCLUDED
export SOURCE_FILE=$1 # First argument is the input file (e.g., cloud_name) 
export RESULT_FILE=$2 # FILE With th eresults

export VOXEL_SIZE=${3:-0.02}
export TILE_SIZE=${4:-10}
export TILE_BUFFER=${5:-0}
export CORES=${5:-1}


export LOG_FILE="$RESULT_FILE.log"
echo "$(date) node ready" >> $LOG_FILE
echo "$SCRATCHDIR" >> $LOG_FILE

# move to scratch
cd $SCRATCHDIR

cd $SCRATCHDIR &>> $LOG_FILE
cp $SOURCE_FILE $SCRATCHDIR/in.laz &>> $LOG_FILE