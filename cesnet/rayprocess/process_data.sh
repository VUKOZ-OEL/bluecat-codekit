# init files names
DATA_PLY="cloud.ply"
TERRAIN_PLY="cloud_mesh.ply"
TRUNKS_TXT="cloud_trunks.txt"
FOREST_TXT="cloud_forest.txt"
SEGMENTED_PLY="cloud_segmented.ply"
TREES_TXT="cloud_trees.txt"
TREES_MESH_PLY="cloud_trees_mesh.ply"
LEAVES_PLY="cloud_leaves.ply"
FIRST_POINT_JSON="${SOURCE_DATA}.first.json"
TREE_INFO_GEOJSON="${SOURCE_DATA}.treeInfo.geojson"

if ! source georeference_results.sh; then
    echo "$(date) ERROR: failed to load georeference_results.sh" >> "$LOG_FILE"
    return 1
fi
georeference_log "loaded georeference_results.sh"

run_logged() {
    local description="$1"
    local exit_code
    shift

    log_message "$description started"
    "$@" >> "$LOG_FILE" 2>&1
    exit_code=$?
    if [ "$exit_code" -eq 0 ]; then
        log_message "$description completed (exit code 0)"
    else
        log_message "ERROR: $description failed (exit code $exit_code); command: $*"
    fi
    return "$exit_code"
}


echo "$(date) pdal processing start" >> $LOG_FILE
run_logged "PDAL preprocessing" singularity exec -B "$SCRATCHDIR":/data ./pdal.img \
    pdal pipeline /data/pdal_pipeline.json || return 1
echo "$(date) pdal processing end" >> $LOG_FILE
georeference_log "PDAL preprocessing completed; cloud.laz is the common coordinate and quantisation reference"

# RayCloudTools shifts this exact cloud by its first point when
# --remove_start_pos is used. Persist that translation for the results and
# reuse it below to restore absolute coordinates.
save_first_point_coordinates "cloud.laz" "$FIRST_POINT_JSON" || {
    echo "$(date) failed to save first-point coordinates" >> "$LOG_FILE"
    return 1
}
echo "$(date) first-point coordinates saved to $FIRST_POINT_JSON" >> "$LOG_FILE"

echo "$(date) raycloudtools processing start" >> $LOG_FILE
# RUN raycloudtools in singularity to process the data

if [ "$TRAJECTORY" != "false" ]; then
    run_logged "rayimport with trajectory $TRAJECTORY" \
        singularity exec -B "$SCRATCHDIR":/data ./raycloudtools.img \
        rayimport cloud.laz "$TRAJECTORY" --remove_start_pos || return 1
else
    run_logged "rayimport with fixed ray" \
        singularity exec -B "$SCRATCHDIR":/data ./raycloudtools.img \
        rayimport cloud.laz ray 0,0,-10 --remove_start_pos || return 1
fi


echo "$(date) loaded" >> $LOG_FILE
run_logged "rayextract terrain" singularity exec -B "$SCRATCHDIR":/data ./raycloudtools.img \
    rayextract terrain "$DATA_PLY" || return 1
echo "$(date) terrain extracted" >> $LOG_FILE
run_logged "rayextract trunks" singularity exec -B "$SCRATCHDIR":/data ./raycloudtools.img \
    rayextract trunks "$DATA_PLY" || return 1
echo "$(date) trunks extracted" >> $LOG_FILE
run_logged "rayextract forest" singularity exec -B "$SCRATCHDIR":/data ./raycloudtools.img \
    rayextract forest "$DATA_PLY" || return 1
echo "$(date) forest extracted" >> $LOG_FILE

#singularity exec -B $SCRATCHDIR/:/data ./raycloudtools.img rayextract trees $DATA_PLY $TERRAIN_PLY

# In case of insufficient RAM, retry tree extraction with progressively
# stronger ray decimation. The first attempt uses the complete cloud.
if ! cp "$DATA_PLY" cloud_decimated.ply >> "$LOG_FILE" 2>&1; then
    log_message "ERROR: unable to initialise cloud_decimated.ply from $DATA_PLY"
    log_message "available PLY files: $(find . -maxdepth 1 -name '*.ply' -printf '%f ' 2>/dev/null)"
    return 1
fi
log_message "tree extraction input initialised: $DATA_PLY -> cloud_decimated.ply"

decimation_level=1
while true; do
    if [ "$decimation_level" -eq 1 ]; then
        extraction_description="rayextract trees at full resolution"
    else
        extraction_description="rayextract trees from every ${decimation_level}-th ray"
    fi

    if run_logged "$extraction_description" \
        singularity exec -B "$SCRATCHDIR":/data ./raycloudtools.img \
        rayextract trees cloud_decimated.ply "$TERRAIN_PLY"; then
        missing_outputs=""
        for expected_output in cloud_decimated_segmented.ply cloud_decimated_trees.txt cloud_decimated_trees_mesh.ply; do
            if [ ! -s "$expected_output" ]; then
                missing_outputs="$missing_outputs $expected_output"
            fi
        done
        if [ -n "$missing_outputs" ]; then
            log_message "ERROR: rayextract trees returned exit code 0 but outputs are missing or empty:$missing_outputs"
            return 1
        fi

        mv cloud_decimated_segmented.ply "$SEGMENTED_PLY" || return 1
        mv cloud_decimated_trees.txt "$TREES_TXT" || return 1
        mv cloud_decimated_trees_mesh.ply "$TREES_MESH_PLY" || return 1
        rm -f cloud_decimated.ply
        log_message "trees extracted successfully; required outputs verified"
        break
    fi

    if [ "$decimation_level" -eq 1 ]; then
        next_decimation_level=2
    else
        next_decimation_level=$((decimation_level + 2))
    fi
    if [ "$next_decimation_level" -gt 10 ]; then
        log_message "ERROR: rayextract trees failed at all levels (full, 2, 4, 6, 8, 10); aborting before dependent steps"
        return 1
    fi

    rm -f cloud_decimated.ply
    run_logged "raydecimate to every ${next_decimation_level}-th ray" \
        singularity exec -B "$SCRATCHDIR":/data ./raycloudtools.img \
        raydecimate "$DATA_PLY" "$next_decimation_level" rays || return 1
    if [ ! -s cloud_decimated.ply ]; then
        log_message "ERROR: raydecimate succeeded but cloud_decimated.ply is missing or empty"
        return 1
    fi
    decimation_level="$next_decimation_level"
done


run_logged "rayextract leaves" singularity exec -B "$SCRATCHDIR":/data ./raycloudtools.img \
    rayextract leaves "$DATA_PLY" "$TREES_TXT" || return 1
echo "$(date) leaves extracted" >> $LOG_FILE
run_logged "treeinfo" singularity exec -B "$SCRATCHDIR":/data ./raycloudtools.img \
    treeinfo "$TREES_TXT" || return 1
echo "$(date) treeinfo extracted" >> $LOG_FILE

if [ ! -s cloud_trees_info.txt ]; then
    log_message "ERROR: treeinfo returned success but cloud_trees_info.txt is missing or empty"
    return 1
fi
create_tree_info_geojson "cloud_trees_info.txt" "$TREE_INFO_GEOJSON" || {
    log_message "ERROR: failed to create georeferenced tree-info GeoJSON from cloud_trees_info.txt"
    return 1
}
echo "$(date) georeferenced tree info saved to $TREE_INFO_GEOJSON" >> "$LOG_FILE"

echo "lof in SCRATCHDIR:" >> $LOG_FILE
echo "$(ls -lh)" >> $LOG_FILE
echo "" >> $LOG_FILE

# Create images for each segmented tree
SEGMENT_DIR="${SCRATCHDIR}/segments"
if ! mkdir -p "$SEGMENT_DIR"; then
    log_message "ERROR: unable to create segment directory $SEGMENT_DIR"
    return 1
fi
if ! cp "$SEGMENTED_PLY" "segments/$SEGMENTED_PLY"; then
    log_message "ERROR: unable to copy $SEGMENTED_PLY into segment directory"
    return 1
fi
run_logged "raysplit segmented cloud by tree colour" \
    singularity exec -B "$SCRATCHDIR":/data ./raycloudtools.img \
    raysplit "segments/$SEGMENTED_PLY" seg_colour || return 1

echo "$(date) segments extracted" >> $LOG_FILE

tree_segment_count=0
for segment_file in "$SEGMENT_DIR"/*.ply; do
    segment_name=$(basename "$segment_file")
    if [ "$segment_name" = "$SEGMENTED_PLY" ]; then
        continue
    fi
    tree_segment_count=$((tree_segment_count + 1))
    segment_relative="segments/$segment_name"
    segment_laz="${segment_relative%.ply}.laz"
    segment_traj="${segment_relative%.ply}.txt"

    run_logged "rayrender $segment_relative" \
        singularity exec -B "$SCRATCHDIR":/data ./raycloudtools.img \
        rayrender "/data/$segment_relative" right ends || return 1
    run_logged "rayexport $segment_relative" \
        singularity exec -B "$SCRATCHDIR":/data ./raycloudtools.img \
        rayexport "/data/$segment_relative" "/data/$segment_laz" "/data/$segment_traj" || return 1
    georeference_log "rayexport completed without coordinate modification: $segment_relative -> $segment_laz"
    georeference_rayexport_laz "$segment_laz" || {
        echo "$(date) failed to georeference $segment_laz" >> "$LOG_FILE"
        return 1
    }
    run_logged "raywrap $segment_relative" \
        singularity exec -B "$SCRATCHDIR":/data ./raycloudtools.img \
        raywrap "/data/$segment_relative" inwards 1.0 || return 1
    #echo "Rendered image for $segment_file" >> $LOG_FILE
done

if [ "$tree_segment_count" -eq 0 ]; then
    log_message "ERROR: raysplit produced no individual tree PLY files"
    return 1
fi

echo "$(date) $tree_segment_count individual tree segments exported" >> $LOG_FILE
