#!/bin/bash

# Assign input arguments to variables
INPUT_FILE=$1    # First argument is the input file (e.g., data.laz)
OUTPUT_FILE=$2   # Second argument is the output file (e.g., cloud.laz)
VOXELIZE=$3      # Third argument is true/false for voxelization
ADD_TIME=$4      # Fourth argument is true/false for adding GPS time
VOX_RES=$5       # Fifth argument is the voxel resolution (e.g., 0.01)

# Initialize the basic part of the PDAL pipeline (read input file)
pipeline="{
  \"pipeline\": [
    {
      \"type\": \"readers.las\",
      \"filename\": \"$INPUT_FILE\"
    }"

# If VOXELIZE is set to true, add the voxelgrid filter to the pipeline
if [ "$VOXELIZE" == "true" ]; then
  pipeline+=",{
      \"type\": \"filters.voxelgrid\",
      \"leaf_x\": $VOX_RES,
      \"leaf_y\": $VOX_RES,
      \"leaf_z\": $VOX_RES
    }"
fi

# If ADD_TIME is set to true, add a filter to copy X dimension into GpsTime
if [ "$ADD_TIME" == "true" ]; then
  pipeline+=",{
      \"type\": \"filters.ferry\",
      \"dimensions\": \"X=>GpsTime\"
    }"
fi

# Final part of the pipeline: save the output as a .laz file with LAS 1.2 format
pipeline+=",{
      \"type\": \"writers.las\",
      \"compression\": \"laszip\",
      \"filename\": \"$OUTPUT_FILE\",
      \"minor_version\": 2
    }
  ]
}"

# Write the pipeline JSON to a file for debugging or logging purposes
echo "$pipeline" > pdal_pipeline.json


