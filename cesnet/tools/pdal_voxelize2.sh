#!/bin/bash

# set variables, PATH INCLUDED
export SOURCE_FILE=$1 # First argument is the input file (e.g., cloud_name) 
export RESULT_FILE=$2 # FILE With the eresults

export VOXEL_SIZE=${3:-0.005}



export LOG_FILE="$RESULT_FILE.log"
echo "$(date) node ready" >> $LOG_FILE
echo "$SCRATCHDIR" >> $LOG_FILE

# move to scratch
cd $SCRATCHDIR

cd $SCRATCHDIR &>> $LOG_FILE
cp $SOURCE_FILE $SCRATCHDIR/in.laz &>> $LOG_FILE

module add singul/ &>> $LOG_FILE

cp /storage/projects2/InterCOST/singularity_img/pdal.img $SCRATCHDIR &>> $LOG_FILE

# create pre-processing pipeline
INPUT_FILE="in.laz"  # First argument is the input file (e.g., data.laz)
OUTPUT_FILE="cloud.laz"
# Initialize the basic part of the PDAL pipeline (read input file)
cat <<EOF > pdal_pipeline.json
{
  "pipeline": [
    {
      "type": "readers.las",
      "filename": "$INPUT_FILE"
    },
    {
      "type": "filters.voxeldownsize",
      "cell": $VOXEL_SIZE,
      "mode": "center"
    },
    {
      "type": "writers.las",
      "dataformat_id": 1,
      "minor_version": 2,
      "filename": "$OUTPUT_FILE"
    }
  ]
}
EOF

singularity exec -B $SCRATCHDIR/:/data ./pdal.img pdal pipeline /data/pdal_pipeline.json

cp $OUTPUT_FILE $RESULT_FILE &>> $LOG_FILE
#clean_scratch