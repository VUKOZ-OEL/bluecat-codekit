#!/bin/bash

# Utilities for restoring the absolute coordinates removed by
# `rayimport --remove_start_pos`.  The functions only depend on tools already
# required by this pipeline: PDAL (inside pdal.img), awk and standard shell
# utilities.

georeference_log() {
    local message="$*"
    if declare -F log_message >/dev/null; then
        log_message "[georeference] $message"
    elif [ -n "${LOG_FILE:-}" ]; then
        echo "$(date) [georeference] $message" >> "$LOG_FILE"
    else
        echo "$(date) [georeference] $message" >&2
    fi
}

extract_first_point_dimension() {
    local info_file="$1"
    local dimension="$2"

    # pdal info formats JSON over multiple lines today. Splitting on commas as
    # well keeps this parser working if a future version emits compact JSON.
    tr ',' '\n' < "$info_file" | awk -v key="\"${dimension}\"" '
        index($0, key) {
            value = $0
            sub("^.*\"" dimension "\"[[:space:]]*:[[:space:]]*", "", value)
            sub(/[}].*$/, "", value)
            gsub(/[[:space:]]/, "", value)
            print value
            exit
        }
    ' dimension="$dimension"
}

is_json_number() {
    printf '%s\n' "$1" | awk '
        /^[+-]?([0-9]+([.][0-9]*)?|[.][0-9]+)([eE][+-]?[0-9]+)?$/ { valid = 1 }
        END { exit(valid ? 0 : 1) }
    '
}

save_first_point_coordinates() {
    local cloud_file="$1"
    local output_file="$2"
    local raw_info="cloud.first-point.pdal.json"

    georeference_log "reading first point from $cloud_file"
    if ! singularity exec -B "$SCRATCHDIR":/data ./pdal.img \
        pdal info -p 0 "/data/$cloud_file" > "$raw_info" 2>> "$LOG_FILE"; then
        georeference_log "ERROR: pdal info -p 0 failed for $cloud_file"
        return 1
    fi

    FIRST_POINT_X=$(extract_first_point_dimension "$raw_info" X)
    FIRST_POINT_Y=$(extract_first_point_dimension "$raw_info" Y)
    FIRST_POINT_Z=$(extract_first_point_dimension "$raw_info" Z)
    rm -f "$raw_info"

    if ! is_json_number "$FIRST_POINT_X" || \
       ! is_json_number "$FIRST_POINT_Y" || \
       ! is_json_number "$FIRST_POINT_Z"; then
        echo "Unable to read XYZ of the first point from $cloud_file" >&2
        georeference_log "ERROR: invalid first-point XYZ (X=$FIRST_POINT_X, Y=$FIRST_POINT_Y, Z=$FIRST_POINT_Z)"
        return 1
    fi

    printf '{\n  "X": %s,\n  "Y": %s,\n  "Z": %s\n}\n' \
        "$FIRST_POINT_X" "$FIRST_POINT_Y" "$FIRST_POINT_Z" > "$output_file"

    export FIRST_POINT_X FIRST_POINT_Y FIRST_POINT_Z
    georeference_log "first point: X=$FIRST_POINT_X Y=$FIRST_POINT_Y Z=$FIRST_POINT_Z; wrote $output_file"
}

save_las_scale_and_offset() {
    local cloud_file="$1"
    local raw_metadata="las-metadata.$(basename "$cloud_file").pdal.json"

    georeference_log "reading LAS scale and offset from $cloud_file"
    if ! singularity exec -B "$SCRATCHDIR":/data ./pdal.img \
        pdal info --metadata "/data/$cloud_file" > "$raw_metadata" 2>> "$LOG_FILE"; then
        georeference_log "ERROR: pdal info --metadata failed for $cloud_file"
        return 1
    fi

    LAS_SCALE_X=$(extract_first_point_dimension "$raw_metadata" scale_x)
    LAS_SCALE_Y=$(extract_first_point_dimension "$raw_metadata" scale_y)
    LAS_SCALE_Z=$(extract_first_point_dimension "$raw_metadata" scale_z)
    LAS_OFFSET_X=$(extract_first_point_dimension "$raw_metadata" offset_x)
    LAS_OFFSET_Y=$(extract_first_point_dimension "$raw_metadata" offset_y)
    LAS_OFFSET_Z=$(extract_first_point_dimension "$raw_metadata" offset_z)
    rm -f "$raw_metadata"

    if ! is_json_number "$LAS_SCALE_X" || \
       ! is_json_number "$LAS_SCALE_Y" || \
       ! is_json_number "$LAS_SCALE_Z" || \
       ! is_json_number "$LAS_OFFSET_X" || \
       ! is_json_number "$LAS_OFFSET_Y" || \
       ! is_json_number "$LAS_OFFSET_Z"; then
        echo "Unable to read LAS scale and offset from $cloud_file" >&2
        georeference_log "ERROR: invalid LAS scale/offset read from $cloud_file"
        return 1
    fi

    export LAS_SCALE_X LAS_SCALE_Y LAS_SCALE_Z
    export LAS_OFFSET_X LAS_OFFSET_Y LAS_OFFSET_Z
    georeference_log "source rayexport LAS quantisation for $cloud_file: scale=($LAS_SCALE_X,$LAS_SCALE_Y,$LAS_SCALE_Z) offset=($LAS_OFFSET_X,$LAS_OFFSET_Y,$LAS_OFFSET_Z)"
}

log_cloud_state() {
    local cloud_file="$1"
    local stage="$2"
    local safe_name
    local diagnostic_file

    safe_name=$(basename "$cloud_file")
    safe_name="${safe_name%.*}"
    diagnostic_file="segments/${safe_name}.georeference-${stage}.json"
    if singularity exec -B "$SCRATCHDIR":/data ./pdal.img \
        pdal info --metadata -p 0 "/data/$cloud_file" > "$diagnostic_file" 2>> "$LOG_FILE"; then
        georeference_log "$stage state for $cloud_file saved to $diagnostic_file"
        georeference_log "$stage first point for $cloud_file: $(extract_first_point_dimension "$diagnostic_file" X),$(extract_first_point_dimension "$diagnostic_file" Y),$(extract_first_point_dimension "$diagnostic_file" Z)"
    else
        georeference_log "WARNING: unable to inspect $cloud_file at $stage stage"
    fi
}

validate_first_point_transform() {
    local source_ply="$1"
    local laz_file="$2"
    local safe_name
    local source_diagnostic
    local output_diagnostic
    local source_x source_y source_z
    local output_x output_y output_z
    local output_scale_x output_scale_y output_scale_z
    local output_offset_x output_offset_y output_offset_z
    local comparison header_comparison
    local max_scale_steps="${GEOREFERENCE_MAX_SCALE_STEPS:-5}"

    safe_name=$(basename "$source_ply")
    safe_name="${safe_name%.*}"
    source_diagnostic="segments/${safe_name}.georeference-source-ply.json"
    output_diagnostic="segments/${safe_name}.georeference-output-laz.json"

    source_x=$(extract_first_point_dimension "$source_diagnostic" X)
    source_y=$(extract_first_point_dimension "$source_diagnostic" Y)
    source_z=$(extract_first_point_dimension "$source_diagnostic" Z)
    output_x=$(extract_first_point_dimension "$output_diagnostic" X)
    output_y=$(extract_first_point_dimension "$output_diagnostic" Y)
    output_z=$(extract_first_point_dimension "$output_diagnostic" Z)
    output_scale_x=$(extract_first_point_dimension "$output_diagnostic" scale_x)
    output_scale_y=$(extract_first_point_dimension "$output_diagnostic" scale_y)
    output_scale_z=$(extract_first_point_dimension "$output_diagnostic" scale_z)
    output_offset_x=$(extract_first_point_dimension "$output_diagnostic" offset_x)
    output_offset_y=$(extract_first_point_dimension "$output_diagnostic" offset_y)
    output_offset_z=$(extract_first_point_dimension "$output_diagnostic" offset_z)

    if ! is_json_number "$source_x" || ! is_json_number "$source_y" || ! is_json_number "$source_z" || \
       ! is_json_number "$output_x" || ! is_json_number "$output_y" || ! is_json_number "$output_z"; then
        georeference_log "ERROR: unable to validate first point for $laz_file"
        return 1
    fi
    if ! is_json_number "$output_scale_x" || ! is_json_number "$output_scale_y" || ! is_json_number "$output_scale_z" || \
       ! is_json_number "$output_offset_x" || ! is_json_number "$output_offset_y" || ! is_json_number "$output_offset_z"; then
        georeference_log "ERROR: unable to validate LAS scale/offset for $laz_file"
        return 1
    fi
    if ! is_json_number "$max_scale_steps" || \
       ! awk -v steps="$max_scale_steps" 'BEGIN { exit(steps > 0 ? 0 : 1) }'; then
        georeference_log "ERROR: GEOREFERENCE_MAX_SCALE_STEPS must be a positive number; got '$max_scale_steps'"
        return 1
    fi

    # Every exported tree LAZ must share the common cloud.laz quantisation:
    # identical scale in all files, identical offset. Hard check, no tolerance.
    if header_comparison=$(awk \
        -v csx="$LAS_SCALE_X" -v csy="$LAS_SCALE_Y" -v csz="$LAS_SCALE_Z" \
        -v cox="$LAS_OFFSET_X" -v coy="$LAS_OFFSET_Y" -v coz="$LAS_OFFSET_Z" \
        -v osx="$output_scale_x" -v osy="$output_scale_y" -v osz="$output_scale_z" \
        -v oox="$output_offset_x" -v ooy="$output_offset_y" -v ooz="$output_offset_z" '
        function abs(value) { return value < 0 ? -value : value }
        BEGIN {
            printf "scale common=(%.15g,%.15g,%.15g) output=(%.15g,%.15g,%.15g); offset common=(%.15g,%.15g,%.15g) output=(%.15g,%.15g,%.15g)", \
                csx, csy, csz, osx, osy, osz, cox, coy, coz, oox, ooy, ooz
            scale_ok = abs(osx - csx) < 1e-15 && abs(osy - csy) < 1e-15 && abs(osz - csz) < 1e-15
            offset_ok = abs(oox - cox) < 1e-12 && abs(ooy - coy) < 1e-12 && abs(ooz - coz) < 1e-12
            exit(scale_ok && offset_ok ? 0 : 1)
        }
    '); then
        georeference_log "LAS-header validation PASSED for $laz_file: $header_comparison"
    else
        georeference_log "ERROR: LAS-header validation FAILED for $laz_file: $header_comparison"
        return 1
    fi

    # `pdal info` prints large coordinates with limited decimal precision.  A
    # correctly encoded point can therefore appear a few LAS scale steps away
    # from the value calculated from the more precise local coordinate.  Keep
    # this check tight enough to catch centimetre/metre quantisation, while
    # accepting that diagnostic-output rounding.
    if comparison=$(awk \
        -v sx="$source_x" -v sy="$source_y" -v sz="$source_z" \
        -v ox="$output_x" -v oy="$output_y" -v oz="$output_z" \
        -v tx="$FIRST_POINT_X" -v ty="$FIRST_POINT_Y" -v tz="$FIRST_POINT_Z" \
        -v scale_x="$LAS_SCALE_X" -v scale_y="$LAS_SCALE_Y" -v scale_z="$LAS_SCALE_Z" \
        -v max_scale_steps="$max_scale_steps" '
        function abs(value) { return value < 0 ? -value : value }
        BEGIN {
            expected_x = sx + tx
            expected_y = sy + ty
            expected_z = sz + tz
            dx = abs(ox - expected_x)
            dy = abs(oy - expected_y)
            dz = abs(oz - expected_z)
            scale_steps_x = dx / abs(scale_x)
            scale_steps_y = dy / abs(scale_y)
            scale_steps_z = dz / abs(scale_z)
            tolerance_x = abs(scale_x) * max_scale_steps + 1e-12
            tolerance_y = abs(scale_y) * max_scale_steps + 1e-12
            tolerance_z = abs(scale_z) * max_scale_steps + 1e-12
            printf "expected=(%.15g,%.15g,%.15g) actual=(%.15g,%.15g,%.15g) abs_delta=(%.15g,%.15g,%.15g) delta_in_scale_steps=(%.6g,%.6g,%.6g) allowed_scale_steps=%.6g", \
                expected_x, expected_y, expected_z, ox, oy, oz, dx, dy, dz, \
                scale_steps_x, scale_steps_y, scale_steps_z, max_scale_steps
            exit(dx <= tolerance_x && dy <= tolerance_y && dz <= tolerance_z ? 0 : 1)
        }
    '); then
        georeference_log "first-point validation PASSED for $laz_file: $comparison"
    else
        georeference_log "ERROR: first-point validation FAILED for $laz_file: $comparison"
        return 1
    fi
}

georeference_tree_segment() {
    local ply_file="$1"
    local laz_file="$2"
    local rayexport_laz="$3"
    local matrix

    matrix="1 0 0 $FIRST_POINT_X 0 1 0 $FIRST_POINT_Y 0 0 1 $FIRST_POINT_Z 0 0 0 1"

    # RayCloudTools rayexport writes its LAZ ($rayexport_laz) with a one-metre
    # LAS scale and irreversibly rounds point coordinates to whole metres.  That
    # file must therefore NOT be kept as the geometric result — doing so would
    # re-voxelise every tree.  The rayexport step is kept in the pipeline
    # because it also produces the per-segment trajectory text file, but its
    # LAZ output is only a temporary artefact that we discard after the
    # georeferenced LAZ is built directly from the full-precision PLY.

    georeference_log "exporting georeferenced $laz_file directly from PLY $ply_file (bypassing rayexport LAZ quantisation)"
    georeference_log "applying matrix: $matrix"
    georeference_log "common LAS quantisation for ALL tree exports: scale=($LAS_SCALE_X,$LAS_SCALE_Y,$LAS_SCALE_Z) offset=($LAS_OFFSET_X,$LAS_OFFSET_Y,$LAS_OFFSET_Z)"
    log_cloud_state "$ply_file" "source-ply"

    # Write every tree LAZ with the SAME scale and offset read from cloud.laz,
    # so all downstream files share one common quantisation lattice.  PDAL reads
    # the original float PLY coordinates, the transformation filter adds the
    # first-point shift in floating point, and only then is the LAS integer
    # quantisation applied — no intermediate rounding step exists.
    if ! singularity exec -B "$SCRATCHDIR":/data ./pdal.img \
        pdal translate "/data/$ply_file" "/data/$laz_file" transformation \
        --filters.transformation.matrix="$matrix" \
        --writers.las.compression=true \
        --writers.las.minor_version=2 \
        --writers.las.dataformat_id=3 \
        --writers.las.extra_dims=all \
        --writers.las.scale_x="$LAS_SCALE_X" \
        --writers.las.scale_y="$LAS_SCALE_Y" \
        --writers.las.scale_z="$LAS_SCALE_Z" \
        --writers.las.offset_x="$LAS_OFFSET_X" \
        --writers.las.offset_y="$LAS_OFFSET_Y" \
        --writers.las.offset_z="$LAS_OFFSET_Z" >> "$LOG_FILE" 2>&1; then
        georeference_log "ERROR: PDAL PLY-to-georeferenced-LAZ export failed for $ply_file"
        return 1
    fi

    log_cloud_state "$laz_file" "output-laz"
    if ! validate_first_point_transform "$ply_file" "$laz_file"; then
        return 1
    fi

    # rayexport's quantised LAZ is no longer needed; keep only the trajectory.
    if [ -n "$rayexport_laz" ] && [ "$rayexport_laz" != "$laz_file" ] && [ -f "$rayexport_laz" ]; then
        rm -f "$rayexport_laz"
        georeference_log "discarded quantised rayexport LAZ $rayexport_laz (trajectory text kept)"
    fi
    georeference_log "completed georeferenced export for $laz_file"
}

create_dtm_geotiff() {
    local terrain_ply="$1"
    local output_tif="$2"
    local resolution="${3:-0.1}"

    georeference_log "creating DTM GeoTIFF from $terrain_ply at ${resolution} m resolution"

    # cloud_mesh.ply lives in RayCloudTools' local frame (shifted by
    # --remove_start_pos). GeoJSON trees and the final LAZ exports are in the
    # original georeferenced frame. Transform the mesh by the same first-point
    # translation, then rasterise it — so the DMT lines up with the rest.
    local matrix="1 0 0 $FIRST_POINT_X 0 1 0 $FIRST_POINT_Y 0 0 1 $FIRST_POINT_Z 0 0 0 1"

    local pipeline_file="dtm_pipeline.json"
    cat > "$pipeline_file" <<EOF
{
  "pipeline": [
    "/data/$terrain_ply",
    {
      "type": "filters.transformation",
      "matrix": "$matrix"
    },
    {
      "type": "writers.gdal",
      "filename": "/data/$output_tif",
      "resolution": $resolution,
      "output_type": "mean",
      "data_type": "float32",
      "gdaldriver": "GTiff",
      "window_size": 3
    }
  ]
}
EOF

    if ! singularity exec -B "$SCRATCHDIR":/data ./pdal.img \
        pdal pipeline "/data/$pipeline_file" >> "$LOG_FILE" 2>&1; then
        georeference_log "ERROR: PDAL DTM rasterisation failed for $terrain_ply"
        rm -f "$pipeline_file"
        return 1
    fi
    rm -f "$pipeline_file"

    if [ ! -s "$output_tif" ]; then
        georeference_log "ERROR: DTM $output_tif was not created or is empty"
        return 1
    fi
    georeference_log "wrote DTM $output_tif"
}


sample_dtm_at_point() {
    local dtm_tif="$1"
    local x="$2"
    local y="$3"

    # gdallocationinfo outputs the raster value on the last line.  Use
    # bilinear interpolation for sub-pixel accuracy at 10 cm resolution.
    singularity exec -B "$SCRATCHDIR":/data ./pdal.img \
        gdallocationinfo -valonly -b 1 -interp bilinear "/data/$dtm_tif" "$x" "$y" 2>/dev/null | tail -n 1
}


# ---------------------------------------------------------------------------
# DTM helpers -- implementation notes
#
# The previous implementation used gdalallocationinfo with -geoloc, but the
# GDAL CLI in pdal.img rejects that combination of flags at runtime (usage
# message, rc=1).  The osgeo python bindings are not guaranteed to be
# installed in the pdal singularity image either, so the safest path is:
#
#   1. gdal_translate the DMT to an ASCII grid (.xyz), which any GDAL build
#      ships with.
#   2. Pure-Python (no numpy/gdal) read of the grid + bilinear sample.
#   3. Same reader drives both the geojson enrichment and the sqlite writer.
#
# The DMT at 10 cm resolution on a 25x25 m plot is ~250x250 px, so the ASCII
# file is only a few MB -- perfectly fine for a scratch directory.
# ---------------------------------------------------------------------------

sample_dtm_at_point() {
    # legacy shell helper kept for future use; prefers the .xyz path below
    local dtm_xyz="$1" x="$2" y="$3"
    awk -v x0="$x" -v y0="$y" '
        { split($0, a, /[ ]+/); key=a[1]","a[2]; z[key]=a[3] }
        END { print z[x0","y0] }' "$dtm_xyz"
}


dtm_to_xyz() {
    local dtm_tif="$1" out_xyz="$2"
    georeference_log "exporting DTM $dtm_tif to XYZ grid $out_xyz"
    singularity exec -B "$SCRATCHDIR":/data ./pdal.img \
        gdal_translate -of XYZ "/data/$dtm_tif" "/data/$out_xyz" >> "$LOG_FILE" 2>&1 || {
        georeference_log "ERROR: gdal_translate to XYZ failed for $dtm_tif"
        return 1
    }
    [ -s "$out_xyz" ] || { georeference_log "ERROR: $out_xyz is empty"; return 1; }
    return 0
}


# Shared Python helper: opens XYZ grid, samples a list of (x,y) points
# Returns: dict mapping rounded (x,y) -> interpolated Z value, or None.
read_dtm_xyz_pixels() {
    cat <<'PYEOF'
import sys, math

def load_grid(xyz_path):
    # Grid indexed by integer (col, row) -- string float keys in the XYZ file
    # are float64 with ~15 significant digits, so reconstructing them with
    # x0 + col*cell never compares equal and every lookup returns None.
    # Storing by (col, row) avoids that precision trap entirely.
    grid = {}          # (col, row) -> z
    xs_set = set()
    ys_set = set()
    with open(xyz_path) as fh:
        for line in fh:
            parts = line.split()
            if len(parts) < 3:
                continue
            x, y, z = float(parts[0]), float(parts[1]), float(parts[2])
            xs_set.add(x)
            ys_set.add(y)
    xs = sorted(xs_set)
    ys = sorted(ys_set, reverse=True)  # row 0 = northernmost (top of raster)
    if len(xs) < 2 or len(ys) < 2:
        return None
    x0, y_top = xs[0], ys[0]
    cell_x = xs[1] - xs[0]
    cell_y = ys[0] - ys[1]              # positive (ys are descending)
    # Second pass: assign integer col/row by nearest index, robust to
    # sub-ulp shifts from GDAL's float formatting.
    x_index = {x: i for i, x in enumerate(xs)}
    y_index = {y: i for i, y in enumerate(ys)}
    with open(xyz_path) as fh:
        for line in fh:
            parts = line.split()
            if len(parts) < 3:
                continue
            x, y, z = float(parts[0]), float(parts[1]), float(parts[2])
            col = x_index.get(x)
            row = y_index.get(y)
            if col is None or row is None:
                continue
            grid[(col, row)] = z
    return {
        "grid": grid, "x0": x0, "y_top": y_top,
        "cell_x": cell_x, "cell_y": cell_y,
        "ncols": len(xs), "nrows": len(ys),
    }


def sample(g, fx, fy):
    # Bilinear interpolation at fractional (col, row) position
    col = (fx - g["x0"]) / g["cell_x"]
    row = (g["y_top"] - fy) / g["cell_y"]
    col_i, row_i = int(col), int(row)
    if not (0 <= col_i < g["ncols"] - 1 and 0 <= row_i < g["nrows"] - 1):
        return None
    dx, dy = col - col_i, row - row_i
    z00 = g["grid"].get((col_i,     row_i))
    z10 = g["grid"].get((col_i + 1, row_i))
    z01 = g["grid"].get((col_i,     row_i + 1))
    z11 = g["grid"].get((col_i + 1, row_i + 1))
    if z00 is None or z10 is None or z01 is None or z11 is None:
        return None
    return (z00 * (1 - dx) * (1 - dy)
            + z10 * dx * (1 - dy)
            + z01 * (1 - dx) * dy
            + z11 * dx * dy)
PYEOF
}


add_dist2dmt_to_treeinfo() {
    local tree_info_geojson="$1"
    local dtm_tif="$2"
    local dtm_xyz tmp_geojson

    georeference_log "adding dist2dmt from $dtm_tif to $tree_info_geojson"

    dtm_xyz="${dtm_tif%.tif}.xyz"
    dtm_to_xyz "$dtm_tif" "$dtm_xyz" || {
        georeference_log "WARNING: DTM XYZ export failed; skipping dist2dmt"
        return 0
    }

    tmp_geojson="${tree_info_geojson}.tmp"
    cp "$tree_info_geojson" "$tmp_geojson" || return 1

    # Shared python code (helper) + caller script as one heredoc.  This keeps
    # the XYZ loading logic identical between the geojson patch and the
    # sqlite writer below.
    singularity exec -B "$SCRATCHDIR":/data \
        --env GEOJSON_IN="/data/$tmp_geojson" \
        --env DTM_XYZ="/data/$dtm_xyz" \
        ./pdal.img python3 - <<PYEOF
import json, os, sys

$(read_dtm_xyz_pixels)

xyz_path = os.environ["DTM_XYZ"]
geojson_path = os.environ["GEOJSON_IN"]
g = load_grid(xyz_path)
if g is None:
    print("invalid/empty DTM grid", file=sys.stderr)
    sys.exit(2)

with open(geojson_path) as fh:
    data = json.load(fh)

updated = skipped = 0
for feat in data.get("features", []):
    geom = feat.get("geometry", {})
    if geom.get("type") != "Point":
        continue
    coords = geom.get("coordinates") or []
    if len(coords) < 3:
        continue
    x, y, tree_z = coords[0], coords[1], coords[2]

    dtm_z = sample(g, x, y)
    if dtm_z is None:
        skipped += 1
        continue
    props = feat.setdefault("properties", {})
    props.setdefault("dist2dmt", round(tree_z - dtm_z, 3))
    updated += 1

with open(geojson_path, "w") as fh:
    json.dump(data, fh, ensure_ascii=False)

print(f"updated={updated} skipped={skipped} grid={g['ncols']}x{g['nrows']}")
PYEOF

    if [ $? -ne 0 ]; then
        georeference_log "WARNING: dist2dmt enrichment failed; continuing without it"
        rm -f "$tmp_geojson"
        return 0
    fi

    mv "$tmp_geojson" "$tree_info_geojson"
    georeference_log "dist2dmt added to $(grep -c '\"dist2dmt\"' "$tree_info_geojson") tree features"
    return 0
}


create_tree_info_sqlite() {
    local tree_info_geojson="$1"
    local out_sqlite="$2"
    local dtm_tif="$3"
    local dtm_xyz

    georeference_log "writing parallel SQLite tree table to $out_sqlite"

    dtm_xyz="${dtm_tif%.tif}.xyz"
    # XYZ may already exist if add_dist2dmt_to_treeinfo ran first; recreate only if missing
    if [ ! -s "$dtm_xyz" ]; then
        dtm_to_xyz "$dtm_tif" "$dtm_xyz" || {
            georeference_log "WARNING: DTM XYZ export failed; sqlite will still be written"
        }
    fi

    singularity exec -B "$SCRATCHDIR":/data \
        --env GEOJSON_IN="/data/$tree_info_geojson" \
        --env SQLITE_OUT="/data/$out_sqlite" \
        --env DTM_XYZ="/data/$dtm_xyz" \
        ./pdal.img python3 - <<PYEOF 2>>"$LOG_FILE"
import json, os, sqlite3, sys

$(read_dtm_xyz_pixels)

xyz_path = os.environ["DTM_XYZ"]
geojson_path = os.environ["GEOJSON_IN"]
sqlite_path = os.environ["SQLITE_OUT"]

g = load_grid(xyz_path) if os.path.exists(xyz_path) else None

with open(geojson_path) as fh:
    data = json.load(fh)

# Build schema: one column per GeoJSON property key, plus dist2dmt if absent
prop_keys = []
seen = set()
for feat in data.get("features", []):
    for k in (feat.get("properties") or {}).keys():
        if k not in seen:
            seen.add(k)
            prop_keys.append(k)
if "dist2dmt" not in seen:
    prop_keys.append("dist2dmt")

col_defs = ", ".join('"%s" REAL' % k.replace('"', '""') for k in prop_keys)

if os.path.exists(sqlite_path):
    os.unlink(sqlite_path)
conn = sqlite3.connect(sqlite_path)
cur = conn.cursor()
cur.execute(
    'CREATE TABLE trees (fid INTEGER PRIMARY KEY, x REAL, y REAL, z REAL, %s)' % col_defs
)
placeholders = ",".join("?" for _ in prop_keys)
insert_sql = (
    'INSERT INTO trees (fid, x, y, z, %s) VALUES (?,?,?,?,%s)'
    % (", ".join('"%s"' % k.replace('"', '""') for k in prop_keys), placeholders)
)

n_inserted = n_dtm_ok = 0
for feat in data.get("features", []):
    geom = feat.get("geometry", {})
    if geom.get("type") != "Point":
        continue
    coords = geom.get("coordinates") or []
    if len(coords) < 3:
        continue
    x, y, z = coords[0], coords[1], coords[2]
    fid = feat.get("id")
    props = dict(feat.get("properties") or {})

    # Fill dist2dmt from DTM if missing (geojson enrichment may have failed)
    if "dist2dmt" not in props and g is not None:
        dtm_z = sample(g, x, y)
        if dtm_z is not None:
            props["dist2dmt"] = round(z - dtm_z, 3)
            n_dtm_ok += 1

    row_vals = [props.get(k) for k in prop_keys]
    cur.execute(insert_sql, [fid, x, y, z] + row_vals)
    n_inserted += 1

conn.commit()
conn.close()
print(f"sqlite rows inserted={n_inserted} dtm_sampled={n_dtm_ok} columns={len(prop_keys)}")
PYEOF

    RC=$?
    if [ $RC -ne 0 ]; then
        georeference_log "WARNING: sqlite writer returned $RC (non-fatal)"
        return 0
    fi
    georeference_log "wrote $out_sqlite"
    return 0
}

create_tree_info_geojson() {
    local tree_info_file="$1"
    local output_file="$2"

    awk -v offset_x="$FIRST_POINT_X" \
        -v offset_y="$FIRST_POINT_Y" \
        -v offset_z="$FIRST_POINT_Z" '
        function json_escape(value) {
            gsub(/\\/, "\\\\", value)
            gsub(/"/, "\\\"", value)
            gsub(/\r/, "", value)
            gsub(/\n/, "\\n", value)
            return value
        }

        function json_value(value) {
            if (value ~ /^[+-]?([0-9]+([.][0-9]*)?|[.][0-9]+)([eE][+-]?[0-9]+)?$/) {
                return value
            }
            return "\"" json_escape(value) "\""
        }

        function add_property(name, value) {
            if (name == "") return
            name = json_escape(name)
            if (property_count++) properties = properties ","
            properties = properties "\"" name "\":" json_value(value)
        }

        BEGIN {
            print "{\"type\":\"FeatureCollection\",\"features\":["
            first_feature = 1
        }

        /^[[:space:]]*#/ || /^[[:space:]]*$/ { next }

        !header_read {
            header_line = $0
            gsub(/\r/, "", header_line)
            sub(/^[[:space:]]+/, "", header_line)
            sub(/[[:space:]]+$/, "", header_line)
            header_group_count = split(header_line, header_groups, /[[:space:]]+/)

            for (group_index = 1; group_index <= header_group_count; group_index++) {
                field_count[group_index] = split(header_groups[group_index], parsed_header_fields, ",")
                has_x = has_y = has_z = 0
                for (field_index = 1; field_index <= field_count[group_index]; field_index++) {
                    header_field[group_index, field_index] = parsed_header_fields[field_index]
                    name = tolower(header_field[group_index, field_index])
                    if (name == "x") has_x = 1
                    if (name == "y") has_y = 1
                    if (name == "z") has_z = 1
                }
                if (has_x && has_y && has_z) root_group = group_index
            }

            if (!root_group) {
                print "Tree-info header does not contain an XYZ group" > "/dev/stderr"
                exit 2
            }

            header_read = 1
            next
        }

        {
            data_line = $0
            gsub(/\r/, "", data_line)
            sub(/^[[:space:]]+/, "", data_line)
            sub(/[[:space:]]+$/, "", data_line)
            data_group_count = split(data_line, data_groups, /[[:space:]]+/)
            if (data_group_count < root_group) next

            property_count = 0
            properties = ""
            x = y = z = ""

            # Groups before the XYZ group are per-tree attributes. Groups after
            # it are child branch segments and are deliberately not exported.
            for (group_index = 1; group_index < root_group; group_index++) {
                value_count = split(data_groups[group_index], values, ",")
                for (field_index = 1; field_index <= field_count[group_index] && field_index <= value_count; field_index++) {
                    add_property(header_field[group_index, field_index], values[field_index])
                }
            }

            value_count = split(data_groups[root_group], values, ",")
            for (field_index = 1; field_index <= field_count[root_group] && field_index <= value_count; field_index++) {
                name = header_field[root_group, field_index]
                lower_name = tolower(name)
                if (lower_name == "x") x = values[field_index] + offset_x
                else if (lower_name == "y") y = values[field_index] + offset_y
                else if (lower_name == "z") z = values[field_index] + offset_z
                else if (lower_name != "children" && lower_name != "parent_id") add_property(name, values[field_index])
            }

            if (x == "" || y == "" || z == "") next
            if (!first_feature) print ","
            printf "{\"type\":\"Feature\",\"id\":%d,\"geometry\":{\"type\":\"Point\",\"coordinates\":[%.15g,%.15g,%.15g]},\"properties\":{%s}}", \
                ++feature_id, x, y, z, properties
            first_feature = 0
        }

        END {
            print "\n]}"
        }
    ' "$tree_info_file" > "$output_file"
}
