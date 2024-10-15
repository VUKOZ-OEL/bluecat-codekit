
# define file name without extension
DATA=312600_5475300

# define a DATADIR variable
DATADIR=/storage/plzen1/home/krucek/raycloud # substitute username and path to your real username and path

LOG_FILE="$DATADIR/$DATA.info.txt"

# DO NOT EDIT------------------------------------------------------------------

#create info file
echo "$PBS_JOBID is running on node `hostname -f` in a scratch directory $SCRATCHDIR" >> $LOG_FILE

# test if the scratch directory is set
test -n "$SCRATCHDIR" || { echo >&2 "Variable SCRATCHDIR is not set!"; exit 1; }

#loads singularity
module add singul/ || echo "singularity not loaded" >> $DATADIR/jobs_info.txt

# copy input file and raycloudtools to scratch
SOURCE_DATA="${DATA}.laz"
cp /storage/plzen1/home/krucek/raycloudtools.img $SCRATCHDIR 
cp $DATADIR/$SOURCE_DATA  $SCRATCHDIR 

# move into scratch directory
cd $SCRATCHDIR

# init files names
DATA_PLY="${DATA}.ply"
TERRAIN_PLY="${DATA}_mesh.ply"
TRUNKS_TXT="${DATA}_trunks.txt"
FOREST_TXT="${DATA}_forest.txt"
SEGMENTED_PLY="${DATA}_segmented.ply"
TREES_TXT="${DATA}_trees.txt"
TREES_MESH_PLY="${DATA}_trees_mesh.ply"
LEAVES_PLY="${DATA}_leaves.ply"

# RUN raycloudtools in singularity
singularity exec -B $SCRATCHDIR/:/data ./raycloudtools.img rayimport $SOURCE_DATA ray 0,0,-10 --remove_start_pos
singularity exec -B $SCRATCHDIR/:/data ./raycloudtools.img rayextract terrain $DATA_PLY
singularity exec -B $SCRATCHDIR/:/data ./raycloudtools.img rayextract trunks $DATA_PLY
singularity exec -B $SCRATCHDIR/:/data ./raycloudtools.img rayextract forest $DATA_PLY
singularity exec -B $SCRATCHDIR/:/data ./raycloudtools.img rayextract trees $DATA_PLY $TERRAIN_PLY
singularity exec -B $SCRATCHDIR/:/data ./raycloudtools.img rayextract leaves $DATA_PLY $TREES_TXT

# Create a list of generated files
FILES_TO_ZIP=("$DATA_PLY" "$TERRAIN_PLY" "$TRUNKS_TXT" "$FOREST_TXT" "$SEGMENTED_PLY" "$TREES_TXT" "$TREES_MESH_PLY" "$LEAVES_PLY")

# Check if each file exists and add to the zip
ZIP_NAME="$DATA.zip"
for file in "${FILES_TO_ZIP[@]}"; do
    if [ -f "$file" ]; then
        zip -u "$ZIP_NAME" "$file"
        echo "Added $file to $ZIP_NAME" >> $LOG_FILE
    else
        echo "$file does not exist and will not be added to $ZIP_NAME" >> $LOG_FILE
    fi
done

# Copy the ZIP file to $DATADIR
cp "$ZIP_NAME" $DATADIR
echo "Copied $ZIP_NAME to $DATADIR" >> $LOG_FILE

# clean the SCRATCH directory
clean_scratch