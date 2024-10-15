# define file name without extension
DATA_IN=zofinB

# define a DATADIR variable
DATADIR=/storage/plzen1/home/krucek/InterCOST/data # substitute username and path to your real username and path

# set parameters for data preparation
VOXELIZE="FALSE"
VOX_RES=0.01

# log file definitionls
LOG_FILE="$DATADIR/$DATA_IN.info.txt"

# DO NOT EDIT------------------------------------------------------------------
DATA="data"
SOURCE_DATA="${DATA}.laz"
#create info file
echo "$PBS_JOBID is running on node `hostname -f` in a scratch directory $SCRATCHDIR" >> $LOG_FILE

# test if the scratch directory is set
test -n "$SCRATCHDIR" || { echo >&2 "Variable SCRATCHDIR is not set!"; exit 1; }

#loads singularity
module add singul/ || echo "singularity not loaded" >> $DATADIR/jobs_info.txt

# copy input file and raycloudtools to scratch
SOURCE_DATA="${DATA}.laz"
# copy data
cp $DATADIR/${DATA_IN}.laz  $SCRATCHDIR/$SOURCE_DATA
# copy images
cp /storage/plzen1/home/krucek/InterCOST/img/raycloudtools.img $SCRATCHDIR 
cp /storage/plzen1/home/krucek/InterCOST/img/r-lidar-tools.img $SCRATCHDIR
cp /storage/plzen1/home/krucek/InterCOST/img/pdal.img $SCRATCHDIR
# copy scripts
cp /storage/plzen1/home/krucek/InterCOST/src/voxelize_add_gpst.R $SCRATCHDIR
cp /storage/plzen1/home/krucek/InterCOST/src/pdal_pipeline.json $SCRATCHDIR

# move into scratch directory
cd $SCRATCHDIR

# init files namesmodule add 
DATA_PLY="${DATA}.ply"
TERRAIN_PLY="${DATA}_mesh.ply"
TRUNKS_TXT="${DATA}_trunks.txt"
FOREST_TXT="${DATA}_forest.txt"
SEGMENTED_PLY="${DATA}_segmented.ply"
TREES_TXT="${DATA}_trees.txt"
TREES_MESH_PLY="${DATA}_trees_mesh.ply"
LEAVES_PLY="${DATA}_leaves.ply"


# RUN r-lidar-tools 
singularity exec -B $SCRATCHDIR/:/data ./r-lidar-tools.img Rscript /data/voxelize_add_gpst.R $SCRATCHDIR $VOX_RES $VOXELIZE


# RUN raycloudtools in singularity to process the data
singularity exec -B $SCRATCHDIR/:/data ./raycloudtools.img rayimport $SOURCE_DATA ray 0,0,-10 --remove_start_pos
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
rm $SOURCE_DATA 
rm rm raycloudtools.img
#find segments/ -type f -name "*.ply" -delete
rm $DATA_PLY
rm segments/$DATA_PLY

# Create a ZIP file containing all results
ZIP_NAME="${DATA_IN}_results.zip"
zip -r "$ZIP_NAME" .

# Copy the ZIP file to $DATADIR
cp "$ZIP_NAME" $DATADIR
echo "Copied $ZIP_NAME to $DATADIR" >> $LOG_FILE


# clean the SCRATCH directory
clean_scratch
