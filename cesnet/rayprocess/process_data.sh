# init files names
DATA_PLY="cloud.ply"
TERRAIN_PLY="cloud_mesh.ply"
TRUNKS_TXT="cloud_trunks.txt"
FOREST_TXT="cloud_forest.txt"
SEGMENTED_PLY="cloud_segmented.ply"
TREES_TXT="cloud_trees.txt"
TREES_MESH_PLY="cloud_trees_mesh.ply"
LEAVES_PLY="cloud_leaves.ply"


echo "$(date) pdal processing start" >> $LOG_FILE
singularity exec -B $SCRATCHDIR/:/data ./pdal.img pdal pipeline /data/pdal_pipeline.json
echo "$(date) pdal processing end" >> $LOG_FILE



echo "$(date) raycloudtools processing start" >> $LOG_FILE
# RUN raycloudtools in singularity to process the data
singularity exec -B $SCRATCHDIR/:/data ./raycloudtools.img rayimport cloud.laz ray 0,0,-10 --remove_start_pos
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