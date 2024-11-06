#!/bin/sh

# ADJUST ACCORDINGLY

INPUT_DATA=${1:-fileName.laz}
SURVEY_XML=${2:-survey_file.xml}
LOADER_XML=${3:-loader_file.xml}
DATADIR=${4:-/path/to/dir/with/data}


LOG_FILE="$DATADIR/$INPUT_DATA.log"

echo $INPUT_DATA >> $LOG_FILE
echo $SURVEY_XML >> $LOG_FILE
echo $LOADER_XML >> $LOG_FILE
echo $DATADIR >> $LOG_FILE

echo "$(date)  job started" >> $LOG_FILE
echo "$PBS_JOBID is running on node `hostname -f`" >> $LOG_FILE


# PROCESSING
# go to scratch
echo "move to scratch: $SCRATCHDIR" >> $LOG_FILE
cd $SCRATCHDIR

# get & setup helios
echo "setting HELIOS" >> $LOG_FILE
wget https://github.com/3dgeo-heidelberg/helios/releases/download/v1.3.0/helios-plusplus-lin.tar.gz
tar -xzvf helios-plusplus-lin.tar.gz
export LD_LIBRARY_PATH=$SCRATCHDIR/helios-plusplus-lin/run:$LD_LIBRARY_PATH
HELIOS="./helios-plusplus-lin/run/helios"
chmod +x $HELIOS

# copy data
echo "copying the data" >> $LOG_FILE
cp $DATADIR/$INPUT_DATA $SCRATCHDIR/helios-plusplus-lin
cp $DATADIR/$SURVEY_XML $SCRATCHDIR/helios-plusplus-lin
cp $DATADIR/$LOADER_XML $SCRATCHDIR/helios-plusplus-lin

echo "data copyied" >> $LOG_FILE

echo ls -lh >> $LOG_FILE

# test helios
cd helios-plusplus-lin
echo "$(date)  test HELIOS:" >> $LOG_FILE
run/helios --test >> $LOG_FILE
echo " " >> $LOG_FILE

echo "$(date)  run HELIOS:" >> $LOG_FILE
# run simulation, to call helios executable use $HELIOS as a shortcut to whole path 
./run/helios $SCRATCHDIR/helios-plusplus-lin/$SURVEY_XML


# zip and copy results back to datadir
echo "$(date)  compress output:" >> $LOG_FILE
ZIP_NAME="${INPUT_DATA}_helios.zip"
zip -r "$ZIP_NAME" output
echo "$(date)  copy results back" >> $LOG_FILE
cp "$ZIP_NAME" $DATADIR

echo "$(date)  all done, clean_scratch" >> $LOG_FILE
clean_scratch
