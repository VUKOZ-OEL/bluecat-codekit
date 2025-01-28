#!/bin/bash

# move to scratch
cd $SCRATCHDIR
# get source code


# set variables, PATH INCLUDED
export SOURCE_FILE=$1 # First argument is the input file (e.g., cloud_name) 
export RESULT_FILE=$2 # FILE With th eresults

export VOXEL_SIZE=${3:-0.02}
export TILE_SIZE=${4:-10}
export TILE_BUFFER=${5:-0}
export CORES=${5:-1}


cp $SOURCE_FILE $SCRATCHDIR/in.laz

mkdir tiles
mkdir voxelized

wget https://downloads.rapidlasso.de/LAStools.tar.gz

tar xvzf LAStools.tar.gz
rm LAStools.tar.gz

./bin/lasindex64 -i in.laz
./bin/lastile64 -i in.laz -odir tiles -tile_size $TILE_SIZE -buffer $TILE_BUFFER -cores $CORES
rm in.laz
./bin/lasvoxel64 -i tiles/*.las -odir voxelized -step $VOXEL_SIZE -cores $CORES
./bin/lasmerge64 -i voxelized/*.las -o merged.laz

cp merged.laz $RESULT_FILE
clean_scratch
