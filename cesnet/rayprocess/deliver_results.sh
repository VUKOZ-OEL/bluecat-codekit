



# Create a ZIP file containing all results
ZIP_NAME="${DATA}_results.zip"
zip -r "$ZIP_NAME" .

echo "$(date) compressed" >> $LOG_FILE

# Copy the ZIP file to $DATADIR
cp "$ZIP_NAME" $DATADIR
echo "$(date) Copied $ZIP_NAME to $DATADIR" >> $LOG_FILE