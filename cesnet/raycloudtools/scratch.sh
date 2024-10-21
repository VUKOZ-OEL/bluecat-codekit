# define file name without extension
FILE_IN=data_sample.laz

# define a DATADIR variable
DATADIR=/storage/plzen1/home/krucek/InterCOST/data # substitute username and path to your real username and path

# set parameters for data preparation
VOXELIZE="true"         # Set true/false for voxelization
ADD_TIME="true"        # Set true/false for adding GPS time
VOX_RES=0.01            # Voxel resolution to be used

# log file definitionls
LOG_FILE="$DATADIR/$FILE_IN.info.txt"

# DO NOT EDIT------------------------------------------------------------------

#create info file
echo "$PBS_JOBID is running on node `hostname -f` in a scratch directory $SCRATCHDIR" >> $LOG_FILE
# test if the scratch directory is set
test -n "$SCRATCHDIR" || { echo >&2 "Variable SCRATCHDIR is not set!"; exit 1; }
# move into scratch directory
cd $SCRATCHDIR

#load singularity
module add singul/ || echo "singularity not loaded" >> $DATADIR/jobs_info.txt

## Define local data files names
DATA="data"
SOURCE_DATA="${DATA}.laz" 
PDAL_FILE="cloud.laz" # Output pdal file name

RAY_PREFIX="ray"
DATA_PLY="${RAY_PREFIX}.ply"
TERRAIN_PLY="${RAY_PREFIX}_mesh.ply"
TRUNKS_TXT="${RAY_PREFIX}_trunks.txt"
FOREST_TXT="${RAY_PREFIX}_forest.txt"
SEGMENTED_PLY="${RAY_PREFIX}_segmented.ply"
TREES_TXT="${RAY_PREFIX}_trees.txt"
TREES_MESH_PLY="${RAY_PREFIX}_trees_mesh.ply"
LEAVES_PLY="${RAY_PREFIX}_leaves.ply"

## copy to scratch
cp $DATADIR/$FILE_IN  $SCRATCHDIR/$SOURCE_DATA            # copy data
cp /storage/plzen1/home/krucek/InterCOST/img/raycloudtools.img $SCRATCHDIR  # copy raycloud image
cp /storage/plzen1/home/krucek/InterCOST/img/pdal.img $SCRATCHDIR # copy pdal image
cp /storage/plzen1/home/krucek/InterCOST/src/create_pdal_pipeline.sh $SCRATCHDIR # copy pdal pipeline generator

echo "Original file size: $(du -h $DATADIR/$FILE_IN)" >> $LOG_FILE
echo "Local file size: $(du -h $SOURCE_DATA)" >> $LOG_FILE


## Prepare data
# create pdal_pipeline.json
chmod +x create_pdal_pipeline.sh
./create_pdal_pipeline.sh "$SOURCE_DATA" "$PDAL_FILE" "$VOXELIZE" "$ADD_TIME" "$VOX_RES"
# run pdal
singularity exec -B $SCRATCHDIR/:/data ./pdal.img pdal pipeline /data/pdal_pipeline.json
# drop source data file
rm $SOURCE_DATA 

echo "PDAL file size: $(du -h $PDAL_FILE)" >> $LOG_FILE

# RUN raycloudtools in singularity to process the data
singularity exec -B $SCRATCHDIR/:/data ./raycloudtools.img rayimport $PDAL_FILE ray 0,0,-10 --remove_start_pos
singularity exec -B $SCRATCHDIR/:/data ./raycloudtools.img rayextract terrain $DATA_PLY
singularity exec -B $SCRATCHDIR/:/data ./raycloudtools.img rayextract trunks $DATA_PLY
singularity exec -B $SCRATCHDIR/:/data ./raycloudtools.img rayextract forest $DATA_PLY
singularity exec -B $SCRATCHDIR/:/data ./raycloudtools.img rayextract trees $DATA_PLY $TERRAIN_PLY
singularity exec -B $SCRATCHDIR/:/data ./raycloudtools.img rayextract leaves $DATA_PLY $TREES_TXT

# Create images for each segmented tree
SEGMENT_DIR="${SCRATCHDIR}/segments"
mkdir -p $SEGMENT_DIR
cp $SEGMENTED_PLY segments/$SEGMENTED_PLY
singularity exec -B $SCRATCHDIR/:/data ./raycloudtools.img raysplit segments/$SEGMENTED_PLY seg_colour

for segment_file in ${SEGMENT_DIR}/*.ply; do
    singularity exec -B $SCRATCHDIR/:/data ./raycloudtools.img rayrender "$segment_file" right ends
    segment_laz="${segment_file%.ply}.laz"
    segment_traj="${segment_file%.ply}.txt"
    singularity exec -B $SCRATCHDIR/:/data ./raycloudtools.img rayexport $segment_file $segment_laz $segment_traj
   # echo "Rendered image for $segment_file" >> $LOG_FILE
done

# remove files which are no to be copied
rm rm raycloudtools.img
#find segments/ -type f -name "*.ply" -delete
rm $DATA_PLY
rm segments/$DATA_PLY

# Create a ZIP file containing all results
ZIP_NAME="${FILE_IN}_results.zip"
zip -r "$ZIP_NAME" .

# Copy the ZIP file to $DATADIR
cp "$ZIP_NAME" $DATADIR
echo "Copied $ZIP_NAME to $DATADIR" >> $LOG_FILE


# clean the SCRATCH directory
#clean_scratch

