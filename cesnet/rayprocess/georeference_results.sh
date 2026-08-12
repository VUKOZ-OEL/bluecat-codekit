#!/bin/bash

# Utilities for restoring the absolute coordinates removed by
# `rayimport --remove_start_pos`.  The functions only depend on tools already
# required by this pipeline: PDAL (inside pdal.img), awk and standard shell
# utilities.

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

    singularity exec -B "$SCRATCHDIR":/data ./pdal.img \
        pdal info -p 0 "/data/$cloud_file" > "$raw_info" || return 1

    FIRST_POINT_X=$(extract_first_point_dimension "$raw_info" X)
    FIRST_POINT_Y=$(extract_first_point_dimension "$raw_info" Y)
    FIRST_POINT_Z=$(extract_first_point_dimension "$raw_info" Z)
    rm -f "$raw_info"

    if ! is_json_number "$FIRST_POINT_X" || \
       ! is_json_number "$FIRST_POINT_Y" || \
       ! is_json_number "$FIRST_POINT_Z"; then
        echo "Unable to read XYZ of the first point from $cloud_file" >&2
        return 1
    fi

    printf '{\n  "X": %s,\n  "Y": %s,\n  "Z": %s\n}\n' \
        "$FIRST_POINT_X" "$FIRST_POINT_Y" "$FIRST_POINT_Z" > "$output_file"

    export FIRST_POINT_X FIRST_POINT_Y FIRST_POINT_Z
}

translate_laz_to_original_coordinates() {
    local laz_file="$1"
    local directory
    local filename
    local temporary_file
    local matrix

    directory=$(dirname "$laz_file")
    filename=$(basename "$laz_file")
    temporary_file="$directory/.${filename%.laz}.absolute.laz"
    matrix="1 0 0 $FIRST_POINT_X 0 1 0 $FIRST_POINT_Y 0 0 1 $FIRST_POINT_Z 0 0 0 1"

    singularity exec -B "$SCRATCHDIR":/data ./pdal.img \
        pdal translate "/data/$laz_file" "/data/$temporary_file" transformation \
        --filters.transformation.matrix="$matrix" \
        --writers.las.forward=all \
        --writers.las.scale_x=auto \
        --writers.las.scale_y=auto \
        --writers.las.scale_z=auto \
        --writers.las.offset_x=auto \
        --writers.las.offset_y=auto \
        --writers.las.offset_z=auto || return 1

    mv "$temporary_file" "$laz_file"
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
