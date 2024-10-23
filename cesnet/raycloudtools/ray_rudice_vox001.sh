# define file name without extension
DATA=SLP_Rudice_clip_vox001_gpst

# define a DATADIR variable
DATADIR=/storage/plzen1/home/krucek/gs-lcr/001 # substitute username and path to your real username and path

LOG_FILE="$DATADIR/$DATA.info.txt"

# DO NOT EDIT------------------------------------------------------------------
# test if the scratch directory is set
test -n "$SCRATCHDIR" || { echo >&2 "Variable SCRATCHDIR is not set!"; exit 1; }

#create info file
echo "$PBS_JOBID is running on node `hostname -f` in a scratch directory $SCRATCHDIR" >> $LOG_FILE
echo "$(date) processing started" >> $LOG_FILE

#loads singularity
module add singul/ || echo "singularity not loaded" >> $LOG_FILE

echo "$(date) singularity loaded" >> $LOG_FILE

# copy input file and raycloudtools to scratch
SOURCE_DATA="${DATA}.laz"
cp /storage/plzen1/home/krucek/singularity_img/raycloudtools.img $SCRATCHDIR 
cp $DATADIR/$SOURCE_DATA  $SCRATCHDIR 

# move into scratch directory
cd $SCRATCHDIR

echo "$(date) data copied" >> $LOG_FILE
echo "lof in SCRATCHDIR:" >> $LOG_FILE
echo "$(ls)" >> $LOG_FILE
echo "" >> $LOG_FILE


# init files names
DATA_PLY="${DATA}.ply"
TERRAIN_PLY="${DATA}_mesh.ply"
TRUNKS_TXT="${DATA}_trunks.txt"
FOREST_TXT="${DATA}_forest.txt"
SEGMENTED_PLY="${DATA}_segmented.ply"
TREES_TXT="${DATA}_trees.txt"
TREES_MESH_PLY="${DATA}_trees_mesh.ply"
LEAVES_PLY="${DATA}_leaves.ply"

echo "$(date) raycloudtools processing start" >> $LOG_FILE
# RUN raycloudtools in singularity to process the data
singularity exec -B $SCRATCHDIR/:/data ./raycloudtools.img rayimport $SOURCE_DATA ray 0,0,-10 --remove_start_pos
echo "$(date) loaded" >> $LOG_FILE
singularity exec -B $SCRATCHDIR/:/data ./raycloudtools.img rayextract terrain $DATA_PLY
echo "$(date) terrain extracted" >> $LOG_FILE
singularity exec -B $SCRATCHDIR/:/data ./raycloudtools.img rayextract trunks $DATA_PLY
echo "$(date) trunks extracted" >> $LOG_FILE
singularity exec -B $SCRATCHDIR/:/data ./raycloudtools.img rayextract forest $DATA_PLY
echo "$(date) forest extracted" >> $LOG_FILE
singularity exec -B $SCRATCHDIR/:/data ./raycloudtools.img rayextract trees $DATA_PLY $TERRAIN_PLY
echo "$(date) trees extracted" >> $LOG_FILE
singularity exec -B $SCRATCHDIR/:/data ./raycloudtools.img rayextract leaves $DATA_PLY $TREES_TXT
echo "$(date) leaves extracted" >> $LOG_FILE

echo "lof in SCRATCHDIR:" >> $LOG_FILE
echo "$(ls -lh)" >> $LOG_FILE
echo "" >> $LOG_FILE

# Create images for each segmented tree
SEGMENT_DIR="${SCRATCHDIR}/segments"
mkdir -p $SEGMENT_DIR
cp $SEGMENTED_PLY segments/$SEGMENTED_PLY
singularity exec -B $SCRATCHDIR/:/data ./raycloudtools.img raysplit segments/$SEGMENTED_PLY seg_colour

echo "$(date) segments extracted" >> $LOG_FILE

for segment_file in ${SEGMENT_DIR}/*.ply; do
    singularity exec -B $SCRATCHDIR/:/data ./raycloudtools.img rayrender "$segment_file" right ends
    segment_laz="${segment_file%.ply}.laz"
    segment_traj="${segment_file%.ply}.txt"
    singularity exec -B $SCRATCHDIR/:/data ./raycloudtools.img rayexport $segment_file $segment_laz $segment_traj
    #echo "Rendered image for $segment_file" >> $LOG_FILE
done

echo "$(date) segments exported" >> $LOG_FILE

# remove files which are no to be copied
rm $SOURCE_DATA 
rm rm raycloudtools.img
#find segments/ -type f -name "*.ply" -delete
rm segments/*.txt
rm $DATA_PLY
rm segments/$DATA_PLY

# Create a ZIP file containing all results
ZIP_NAME="${DATA}_results.zip"
zip -r "$ZIP_NAME" .

echo "$(date) compressed" >> $LOG_FILE

# Copy the ZIP file to $DATADIR
cp "$ZIP_NAME" $DATADIR
echo "$(date) Copied $ZIP_NAME to $DATADIR" >> $LOG_FILE


# clean the SCRATCH directory
clean_scratch
echo "$(date) clean_scratch" >> $LOG_FILE

