#!/bin/bash

#FILESENDER_URL="https://filesender.cesnet.cz/download.php?token=c626d1c4-f5b7-4640-ba14-89f97c530f73&files_ids=671960%2C671959%2C671958%2C671957%2C671956%2C671955"
#S3_TARGET="s3://wp2/FVA-BW/"  # Změň na svůj cílový bucket

cd $SCRATCHDIR

FILESENDER_URL="$1"
S3_TARGET="$2" 

wget --progress=bar:force -O "$SCRATCHDIR/data.zip" "$FILESENDER_URL"

mkdir data
unzip data.zip -d data/


s5cmd --credentials-file "/storage/plzen1/home/krucek/.aws/credentials" --profile s3cmd_access --endpoint-url=https://s3.cl4.du.cesnet.cz cp "data/*" $S3_TARGET

clean_scratch



