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

if [ "$TRAJECTORY" != "false" ]; then
    singularity exec -B $SCRATCHDIR/:/data ./raycloudtools.img rayimport cloud.laz $TRAJECTORY
else
    singularity exec -B $SCRATCHDIR/:/data ./raycloudtools.img rayimport cloud.laz ray 0,0,-10 --remove_start_pos
fi


echo "$(date) loaded" >> $LOG_FILE
singularity exec -B $SCRATCHDIR/:/data ./raycloudtools.img rayextract terrain $DATA_PLY
echo "$(date) terrain extracted" >> $LOG_FILE
singularity exec -B $SCRATCHDIR/:/data ./raycloudtools.img rayextract trunks $DATA_PLY
echo "$(date) trunks extracted" >> $LOG_FILE
singularity exec -B $SCRATCHDIR/:/data ./raycloudtools.img rayextract forest $DATA_PLY
echo "$(date) forest extracted" >> $LOG_FILE

#singularity exec -B $SCRATCHDIR/:/data ./raycloudtools.img rayextract trees $DATA_PLY $TERRAIN_PLY

# In case of insufficent RAM tree exraction is killed on cesnet
# LOOP ITERATIVELY DECIMATES CLOUD BY HALF UNTILL TREES ARE EXTRACTED (start with full resolution)
cp c$DATA_PLY cloud_decimated.ply
decimation_level=2  # Start with raydecimate at every 2nd ray
while true; do
    echo "$(date) attempting to extract trees with decimation level: $decimation_level" >> $LOG_FILE
    singularity exec -B $SCRATCHDIR/:/data ./raycloudtools.img rayextract trees cloud_decimated.ply $TERRAIN_PLY
    
    # Check if the last command was killed
    if [ $? -eq 0 ]; then
        echo "$(date) trees extracted successfully" >> $LOG_FILE
        mv cloud_decimated_segmented.ply cloud_segmented.ply
        mv cloud_decimated_trees.txt cloud_trees.txt
        mv cloud_decimated_trees_mesh.ply cloud_trees_mesh.ply
        rm cloud_decimated.ply
        break  # Exit loop on success
    else
        decimation_level=$((decimation_level + 2))  # Increase decimation by a factor of 2
        echo "$(date) rayextract trees failed, decimating to every $decimation_level-th ray" >> $LOG_FILE
        # Decimate the ray cloud data
        singularity exec -B $SCRATCHDIR:/data ./raycloudtools.img raydecimate $DATA_PLY $decimation_level rays

        # Exit loop if decimation_level reaches 10
        if [ $decimation_level -ge 12 ]; then
            echo "$(date) decimation level reached 10, stopping loop" >> $LOG_FILE
            break
        fi
    fi
done


singularity exec -B $SCRATCHDIR/:/data ./raycloudtools.img rayextract leaves $DATA_PLY $TREES_TXT
echo "$(date) leaves extracted" >> $LOG_FILE
singularity exec -B $SCRATCHDIR/:/data ./raycloudtools.img treeinfo $TREES_TXT
echo "$(date) treeinfo extracted" >> $LOG_FILE

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
    singularity exec -B $SCRATCHDIR/:/data ./raycloudtools.img raywrap "$segment_file" inwards 1.0
    #echo "Rendered image for $segment_file" >> $LOG_FILE
done

echo "$(date) segments exported" >> $LOG_FILE
