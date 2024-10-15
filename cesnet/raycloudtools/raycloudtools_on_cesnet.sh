#PBS -N ray
#PBS -l ncpus=4
#PBS -l walltime=2:00:00
#PBS -l mem=4g
#PBS -j oe
##PBS -l scratch_local=2g

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

echo "Files at begining:" >> $LOG_FILE
ls >> $LOG_FILE
echo "Variables: $SOURCE_DATA $DATA_PLY $TERRAIN_PLY $TRUNKS_TXT $FOREST_TXT $SEGMENTED_PLY $TREES_TXT $TREES_MESH_PLY $LEAVES_PLY" >> $LOG_FILE


# RUN raycloudtools in singularity
# Import data & copy ply to cloud
singularity exec -B $SCRATCHDIR/:/data ./raycloudtools.img rayimport $SOURCE_DATA ray 0,0,-10 --remove_start_pos # import
cp $DATA_PLY $DATADIR 
echo "CP: $DATA_PLY $DATADIR" >> $LOG_FILE

# create and copy terrain
singularity exec -B $SCRATCHDIR/:/data ./raycloudtools.img rayextract terrain $DATA_PLY # _mesh.ply
cp $TERRAIN_PLY $DATADIR 
echo "CP:  $TERRAIN_PLY $DATADIR " >> $LOG_FILE

# Detect trunks
singularity exec -B $SCRATCHDIR/:/data ./raycloudtools.img rayextract trunks $DATA_PLY # _trunks.txt
cp $TRUNKS_TXT $DATADIR 
echo "CP: $TRUNKS_TXT $DATADIR " >> $LOG_FILE

# Segment trees - ALS
singularity exec -B $SCRATCHDIR/:/data ./raycloudtools.img rayextract forest $DATA_PLY # _forest.txt
cp $FOREST_TXT $DATADIR
cp $SEGMENTED_PLY $DATADIR 
echo "CP: $FOREST_TXT $DATADIR & $SEGMENTED_PLY $DATADIR " >> $LOG_FILE

# Segment trees TLS & QSM
singularity exec -B $SCRATCHDIR/:/data ./raycloudtools.img rayextract trees $DATA_PLY $TERRAIN_PLY # _trees.txt & _trees_mesh.ply
cp $TREES_TXT $DATADIR  
cp $TREES_MESH_PLY $DATADIR 
echo "CP: $TREES_TXT $DATADIR  & $TREES_MESH_PLY $DATADIR " >> $LOG_FILE

# Segment leaves
singularity exec -B $SCRATCHDIR/:/data ./raycloudtools.img rayextract leaves $DATA_PLY $TREES_TXT # _leaves.ply
cp $LEAVES_PLY $DATADIR 
echo "CP: $LEAVES_PLY $DATADIR " >> $LOG_FILE


echo "Data processed, files:" >> $LOG_FILE 
ls >> $LOG_FILE

# clean the SCRATCH directory
clean_scratch
