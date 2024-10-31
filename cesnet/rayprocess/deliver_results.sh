
log_message "deliver results start"

<<<<<<< Updated upstream

cp $LOG_FILE log
=======
>>>>>>> Stashed changes

cp $LOG_FILE log

# Create a ZIP file containing all results
ZIP_NAME="${SOURCE_DATA}_results.zip"

log_message "zip file name: $ZIP_NAME"

zip -r "$ZIP_NAME" . 
<<<<<<< Updated upstream
=======

>>>>>>> Stashed changes

echo "$(date) compressed" >> $LOG_FILE

# Copy the ZIP file to $DATADIR
cp "$ZIP_NAME" $DATADIR
echo "$(date) Copied $ZIP_NAME to $DATADIR" >> $LOG_FILE