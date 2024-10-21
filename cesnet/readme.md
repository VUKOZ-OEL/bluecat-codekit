code used to run on cesnet infrastructure


cp /storage/plzen1/home/krucek/ray_processing/singularityfile $SCRATCHDIR
cd $SCRATCHDIR

singularity build --remote r-lidar-tools.sif singularityfile

docker build -t helios .

cp /storage/plzen1/home/krucek/InterCOST/src/rtest.R $SCRATCHDIR
cp /storage/plzen1/home/krucek/InterCOST/img/r-lidar-tools.img $SCRATCHDIR

singularity exec -B $SCRATCHDIR/:/data ./r-lidar-tools.img Rscript /data/rtest.R


cp /storage/plzen1/home/krucek/InterCOST/src/create_pdal_pipeline.sh $SCRATCHDIR
chmod +x create_pdal_pipeline.sh
./create_pdal_pipeline.sh "$SOURCE_DATA" "$PDAL_FILE" "$VOXELIZE" "$ADD_TIME" "$VOX_RES"
cat pdal_pipeline.json
singularity exec -B $SCRATCHDIR/:/data ./pdal.img pdal pipeline /data/pdal_pipeline.json

FILE_SIZE=$(du -h "$FILE_IN")
echo "Original file size: $FILE_SIZE" >> test.txt

echo "Original file size2: $(du -h "$FILE_IN")" >> test.txt


pipeline+=",{
      \"type\": \"writers.las\",
      \"compression\": \"laszip\",
      \"filename\": \"$OUTPUT_FILE\",
      \"minor_version\": 2
    }


qsub -l select=1:ncpus=24:mem=64gb:scratch_local=150gb -l walltime=24:00:00 /storage/plzen1/home/krucek/gs-lcr/001/ray_klepacov1_vox001.sh
qsub -l select=1:ncpus=24:mem=64gb:scratch_local=150gb -l walltime=24:00:00 /storage/plzen1/home/krucek/gs-lcr/001/ray_klepacov2_vox001.sh
qsub -l select=1:ncpus=24:mem=64gb:scratch_local=150gb -l walltime=24:00:00 /storage/plzen1/home/krucek/gs-lcr/001/ray_rudice_vox001.sh