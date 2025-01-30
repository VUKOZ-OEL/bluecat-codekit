#!/bin/bash

# set variables, PATH INCLUDED
export SOURCE_FILE=$1 # First argument is the input file (e.g., cloud_name) 
export RESULT_FILE=$2 # FILE with the results

export VOXEL_SIZE=${3:-0.02}
export TILE_BUFFER=${4:-0}
export CORES=${5:-1}

export LOG_FILE="$RESULT_FILE.log"
echo "$(date) node ready" >> $LOG_FILE
echo "$SCRATCHDIR" >> $LOG_FILE

# move to scratch
cd $SCRATCHDIR
cp $SOURCE_FILE $SCRATCHDIR/in.laz &>> $LOG_FILE

mkdir tiles_25m\mkdir tiles_1m
mkdir voxelized

wget https://downloads.rapidlasso.de/LAStools.tar.gz
tar xvzf LAStools.tar.gz
rm LAStools.tar.gz

echo "$(date) node ready" >> $LOG_FILE
echo "$(ls -lh)" >> $LOG_FILE

echo "Indexing:" >> $LOG_FILE
./bin/lasindex64 -i in.laz &>> $LOG_FILE

echo "Tiling at 25m:" >> $LOG_FILE
./bin/lastile64 -i in.laz -odir tiles_25m -tile_size 25 -buffer $TILE_BUFFER -cores $CORES &>> $LOG_FILE

echo "Tiling at 1m:" >> $LOG_FILE
./bin/lastile64 -i tiles_25m/*.las -odir tiles_1m -tile_size 1 -buffer $TILE_BUFFER -cores $CORES

echo "Drop intermediate data:" >> $LOG_FILE
rm -r tiles_25m &>> $LOG_FILE

echo "Voxelize:" >> $LOG_FILE
./bin/lasvoxel64 -i tiles_1m/*.las -odir voxelized -step $VOXEL_SIZE -cores $CORES &>> $LOG_FILE

echo "Merge:" >> $LOG_FILE
./bin/lasmerge64 -i voxelized/*.las -o merged.laz &>> $LOG_FILE

echo "Return results" >> $LOG_FILE
cp merged.laz $RESULT_FILE &>> $LOG_FILE

echo "Cleaning" >> $LOG_FILE
clean_scratch &>> $LOG_FILE
