log_message "deliver results start"

# Everything produced by the pipeline lives directly in $SCRATCHDIR now, so
# zip the whole directory and ship that one archive to $DATADIR.
#
# Explicitly included:
#   - tree LAZ files in segments/
#   - georeferenced tree info geojson + sqlite + DTM raster
#   - per-segment diagnostic JSONs under segments/
#   - pipeline log files
# and all other intermediate artifacts produced by raycloudtools + PDAL.

echo "lof in SCRATCHDIR:" >> $LOG_FILE
echo "$(ls -lh)" >> $LOG_FILE

# Create a ZIP file containing everything in the working directory
ZIP_NAME="${SOURCE_DATA%.laz}_results.zip"

log_message "zip file name: $ZIP_NAME"

zip -r "$ZIP_NAME" . >> "$LOG_FILE" 2>&1

echo "$(date) compressed" >> $LOG_FILE

# Copy the single ZIP to $DATADIR
cp "$ZIP_NAME" "$DATADIR"
echo "$(date) Copied $ZIP_NAME to $DATADIR" >> $LOG_FILE