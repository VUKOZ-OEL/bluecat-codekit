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
    local raw_metadata="segments/rayexport.las-metadata.pdal.json"

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
    local source_laz="$1"
    local laz_file="$2"
    local safe_name
    local source_diagnostic
    local output_diagnostic
    local source_x source_y source_z
    local output_x output_y output_z
    local source_scale_x source_scale_y source_scale_z
    local source_offset_x source_offset_y source_offset_z
    local output_scale_x output_scale_y output_scale_z
    local output_offset_x output_offset_y output_offset_z
    local comparison header_comparison
    local max_scale_steps="${GEOREFERENCE_MAX_SCALE_STEPS:-5}"

    safe_name=$(basename "$source_laz")
    safe_name="${safe_name%.*}"
    source_diagnostic="segments/${safe_name}.georeference-rayexport-laz.json"
    output_diagnostic="segments/${safe_name}.georeference-output-laz.json"

    source_x=$(extract_first_point_dimension "$source_diagnostic" X)
    source_y=$(extract_first_point_dimension "$source_diagnostic" Y)
    source_z=$(extract_first_point_dimension "$source_diagnostic" Z)
    output_x=$(extract_first_point_dimension "$output_diagnostic" X)
    output_y=$(extract_first_point_dimension "$output_diagnostic" Y)
    output_z=$(extract_first_point_dimension "$output_diagnostic" Z)
    source_scale_x=$(extract_first_point_dimension "$source_diagnostic" scale_x)
    source_scale_y=$(extract_first_point_dimension "$source_diagnostic" scale_y)
    source_scale_z=$(extract_first_point_dimension "$source_diagnostic" scale_z)
    source_offset_x=$(extract_first_point_dimension "$source_diagnostic" offset_x)
    source_offset_y=$(extract_first_point_dimension "$source_diagnostic" offset_y)
    source_offset_z=$(extract_first_point_dimension "$source_diagnostic" offset_z)
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
    if ! is_json_number "$source_scale_x" || ! is_json_number "$source_scale_y" || ! is_json_number "$source_scale_z" || \
       ! is_json_number "$source_offset_x" || ! is_json_number "$source_offset_y" || ! is_json_number "$source_offset_z" || \
       ! is_json_number "$output_scale_x" || ! is_json_number "$output_scale_y" || ! is_json_number "$output_scale_z" || \
       ! is_json_number "$output_offset_x" || ! is_json_number "$output_offset_y" || ! is_json_number "$output_offset_z"; then
        georeference_log "ERROR: unable to validate LAS scale/offset for $laz_file"
        return 1
    fi
    if ! is_json_number "$max_scale_steps" || \
       ! awk -v steps="$max_scale_steps" 'BEGIN { exit(steps > 0 ? 0 : 1) }'; then
        georeference_log "ERROR: GEOREFERENCE_MAX_SCALE_STEPS must be a positive number; got '$max_scale_steps'"
        return 1
    fi

    if header_comparison=$(awk \
        -v ssx="$source_scale_x" -v ssy="$source_scale_y" -v ssz="$source_scale_z" \
        -v sox="$source_offset_x" -v soy="$source_offset_y" -v soz="$source_offset_z" \
        -v osx="$output_scale_x" -v osy="$output_scale_y" -v osz="$output_scale_z" \
        -v oox="$output_offset_x" -v ooy="$output_offset_y" -v ooz="$output_offset_z" \
        -v tx="$FIRST_POINT_X" -v ty="$FIRST_POINT_Y" -v tz="$FIRST_POINT_Z" '
        function abs(value) { return value < 0 ? -value : value }
        BEGIN {
            expected_ox = sox + tx
            expected_oy = soy + ty
            expected_oz = soz + tz
            printf "scale before=(%.15g,%.15g,%.15g) after=(%.15g,%.15g,%.15g); offset expected=(%.15g,%.15g,%.15g) actual=(%.15g,%.15g,%.15g)", \
                ssx, ssy, ssz, osx, osy, osz, expected_ox, expected_oy, expected_oz, oox, ooy, ooz
            scale_ok = abs(osx - ssx) < 1e-15 && abs(osy - ssy) < 1e-15 && abs(osz - ssz) < 1e-15
            offset_ok = abs(oox - expected_ox) < 1e-12 && abs(ooy - expected_oy) < 1e-12 && abs(ooz - expected_oz) < 1e-12
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
        -v scale_x="$source_scale_x" -v scale_y="$source_scale_y" -v scale_z="$source_scale_z" \
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

georeference_rayexport_laz() {
    local laz_file="$1"
    local directory
    local filename
    local temporary_file
    local matrix
    local output_offset_x output_offset_y output_offset_z

    directory=$(dirname "$laz_file")
    filename=$(basename "$laz_file")
    temporary_file="$directory/.${filename%.laz}.georeferenced.laz"
    matrix="1 0 0 $FIRST_POINT_X 0 1 0 $FIRST_POINT_Y 0 0 1 $FIRST_POINT_Z 0 0 0 1"

    # Preserve rayexport's exact integer representation. Adding the same shift
    # to point coordinates and LAS header offsets keeps every stored integer:
    # (xyz + shift - (offset + shift)) / scale == (xyz - offset) / scale.
    if ! save_las_scale_and_offset "$laz_file"; then
        return 1
    fi
    output_offset_x=$(awk -v offset="$LAS_OFFSET_X" -v shift="$FIRST_POINT_X" 'BEGIN { printf "%.17g", offset + shift }')
    output_offset_y=$(awk -v offset="$LAS_OFFSET_Y" -v shift="$FIRST_POINT_Y" 'BEGIN { printf "%.17g", offset + shift }')
    output_offset_z=$(awk -v offset="$LAS_OFFSET_Z" -v shift="$FIRST_POINT_Z" 'BEGIN { printf "%.17g", offset + shift }')

    georeference_log "georeferencing rayexport result $laz_file without changing its integer quantisation"
    georeference_log "applying matrix: $matrix"
    georeference_log "preserving rayexport scale=($LAS_SCALE_X,$LAS_SCALE_Y,$LAS_SCALE_Z)"
    georeference_log "shifting LAS offset from ($LAS_OFFSET_X,$LAS_OFFSET_Y,$LAS_OFFSET_Z) to ($output_offset_x,$output_offset_y,$output_offset_z)"
    log_cloud_state "$laz_file" "rayexport-laz"

    if ! singularity exec -B "$SCRATCHDIR":/data ./pdal.img \
        pdal translate "/data/$laz_file" "/data/$temporary_file" transformation \
        --filters.transformation.matrix="$matrix" \
        --writers.las.forward=all \
        --writers.las.scale_x="$LAS_SCALE_X" \
        --writers.las.scale_y="$LAS_SCALE_Y" \
        --writers.las.scale_z="$LAS_SCALE_Z" \
        --writers.las.offset_x="$output_offset_x" \
        --writers.las.offset_y="$output_offset_y" \
        --writers.las.offset_z="$output_offset_z" >> "$LOG_FILE" 2>&1; then
        georeference_log "ERROR: PDAL georeference failed for rayexport result $laz_file"
        return 1
    fi

    if ! mv "$temporary_file" "$laz_file"; then
        georeference_log "ERROR: unable to replace $laz_file with georeferenced result"
        return 1
    fi
    log_cloud_state "$laz_file" "output-laz"
    if ! validate_first_point_transform "$laz_file" "$laz_file"; then
        return 1
    fi
    georeference_log "completed georeference for rayexport result $laz_file"
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
