#!/bin/bash

# Nastav cestu k adresáři se soubory
export FILE_IN=$1

cd $SCRATCHDIR

module add singul/
cp /storage/plzen1/home/krucek/singularity_img/pdal.img $SCRATCHDIR

cp $FILE_IN $SCRATCHDIR/cloud.laz

    
singularity exec -B $SCRATCHDIR/:/data ./pdal.img pdal info -p 0 cloud.laz > cloud.first

cp cloud.first "${FILE_IN}.first"
    


clean_scratch