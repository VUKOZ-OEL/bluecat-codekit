# ADJUST ACCORDINGLY

INPUT_DATA=${1:-fileName.laz}
SURVEY_XML=${2:-survey_file.xml}
LOADER_XML=${3:-loader_file.xml}
DATADIR=${4:-/path/to/dir/with/data}

#----------------------------------------------------------------------
# define 
export LOG_FILE="$DATADIR/$INPUT_DATA.log"
log_message() {
    local MESSAGE=$1
    echo "$(date) $MESSAGE" >> $LOG_FILE
}
# Export fce
export -f log_message
# start logging
log_message "$(date)  job started"
log_message "$PBS_JOBID is running on node `hostname -f`"

log_message echo $INPUT_DATA

# PROCESSING
# go to scratch
cd $SCRATCHDIR

# get & setup helios
wget https://github.com/3dgeo-heidelberg/helios/releases/download/v1.3.0/helios-plusplus-lin.tar.gz
tar -xzvf helios-plusplus-lin.tar.gz
export LD_LIBRARY_PATH=$SCRATCHDIR/helios-plusplus-lin/run:$LD_LIBRARY_PATH
HELIOS="./helios-plusplus-lin/run/helios"
chmod +x $HELIOS

# copy data
cp $DATADIR/$INPUT_DATA $SCRATCHDIR/helios-plusplus-lin
cp $DATADIR/$SURVEY_XML $SCRATCHDIR/helios-plusplus-lin
cp $DATADIR/$LOADER_XML $SCRATCHDIR/helios-plusplus-lin

# test helios
cd helios-plusplus-lin
run/helios --test >> $LOG_FILE

# run simulation, to call helios executable use $HELIOS as a shortcut to whole path 
run/helios $SCRATCHDIR/helios-plusplus-lin/$SURVEY_XML

# cleanup
#rm helios-plusplus-lin.tar.gz
#rm -r helios-plusplus-lin
#rm $SCRATCHDIR/helios-plusplus-lin/$INPUT_DATA

# zip and copy results back to datadir
ZIP_NAME="${INPUT_DATA}_helios.zip"
zip -r output "$ZIP_NAME" .
cp "$ZIP_NAME" $DATADIR


clean_scratch