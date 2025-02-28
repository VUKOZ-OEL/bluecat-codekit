!/bin/bash

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

mkdir tiles
mkdir voxelized

wget https://downloads.rapidlasso.de/LAStools.tar.gz

tar xvzf LAStools.tar.gz
rm LAStools.tar.gz

echo "$(date) node ready" >> $LOG_FILE
echo "$(ls -lh)" >> $LOG_FILE

echo "Indexing:" >> $LOG_FILE
./bin/lasindex64 -i in.laz &>> $LOG_FILE

echo "Tiling:" >> $LOG_FILE
./bin/lastile64 -i in.laz -odir tiles -tile_size $TILE_SIZE -buffer $TILE_BUFFER -cores $CORES &>> $LOG_FILE

echo "Drop input data:" >> $LOG_FILE
rm in.laz &>> $LOG_FILE

echo "Voxelize:" >> $LOG_FILE
./bin/lasvoxel64 -i tiles/*.las -odir voxelized -step $VOXEL_SIZE -cores $CORES &>> $LOG_FILE

echo "Merge:" >> $LOG_FILE
./bin/lasmerge64 -i voxelized/*.las -o merged.laz &>> $LOG_FILE

echo "Return results" >> $LOG_FILE
cp merged.laz $RESULT_FILE &>> $LOG_FILE

echo "Cleaning" >> $LOG_FILE
clean_scratch &>> $LOG_FILE