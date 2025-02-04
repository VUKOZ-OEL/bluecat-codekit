#!/bin/bash

# Define
export LOG_FILE="$DATADIR/$SOURCE_DATA.info.txt"

log_message() {
    local MESSAGE=$1
    echo "$(date) $MESSAGE" >> $LOG_FILE
}

# Export fce
export -f log_message


#Start logging
log_message "$(date)  job started"
log_message "$PBS_JOBID is running on node `hostname -f`"
test -n "$SCRATCHDIR" && log_message "scratch dir: $SCRATCHDIR" # || { echo >&2 "Variable SCRATCHDIR is not set!"}
# move into scratch directory
cd $SCRATCHDIR && log_message "move to SCRATCHDIR ok" # || echo "error: cd $SCRATCHDIR" >> $LOG_FILE

# monitor system usage
chmod +x sys_monitor.sh
./sys_monitor.sh &
# save process PID
LSU_PID=$!


#load singularity
module add singul/ && log_message "singularity loaded" # || echo "singularity not loaded" >> $LOG_FILE

# copy all to scratc
source setup_scratch.sh && log_message "setup_scratch ok"   # || { echo "Error on setup_scratch" >> $LOG_FILE}

# create pre-processing pipeline
source create_pdal_pipeline.sh && log_message "$(date) create_pdal_pipeline ok" 

# process data
source process_data.sh && log_message "process_data ok"

#cp cloud.laz $DATADIR/cloud.laz

#end sys monitor
#kill -9 $LSU_PID

# drop unnecesary files
source cleanup_scratch.sh && log_message "cleanup_scratch ok"

# copy results back 
source log/deliver_results.sh && log_message "deliver_results ok"

clean_scratch
exit 0