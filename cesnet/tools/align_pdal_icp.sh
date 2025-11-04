#!/bin/bash


set -euo pipefail

# --------- ARGUMENTY ---------
export FIXED_FILE="$1"
export MOVING_FILE="$2"
export RESULT_FILE=${MOVING_FILE%.laz}_icp.laz
export RESULT_METADATA=${MOVING_FILE%.laz}_icp_metadata.json


# --------- LOG ----------
export LOG_FILE="${RESULT_FILE}.log"
echo "$(date) ICP job start" >> "$LOG_FILE"
echo "SCRATCHDIR: ${SCRATCHDIR:-<unset>}" >> "$LOG_FILE"

# --------- PREP SCRATCH ----------
cd "$SCRATCHDIR"
cp "$FIXED_FILE"  "$SCRATCHDIR/fixed.laz"  &>> "$LOG_FILE"
cp "$MOVING_FILE" "$SCRATCHDIR/moving.laz" &>> "$LOG_FILE"

module add singul/ &>> "$LOG_FILE"
cp /storage/projects2/InterCOST/singularity_img/pdal.img "$SCRATCHDIR" &>> "$LOG_FILE"

# --------- PIPELINE ----------
# Pozn.: čteme 2 vstupy (fixed, moving), provedeme filters.icp a uložíme transformované MOVING
cat > "$SCRATCHDIR/pdal_icp.json" <<'JSON'
{
  "pipeline": [
    { "type": "readers.las", "filename": "fixed.laz" },
    { "type": "readers.las", "filename": "moving.laz" },
    {
      "type": "filters.icp",
    },
    {
      "type": "writers.las",
      "minor_version": 2,
      "dataformat_id": 1,
      "filename": "icp.laz"
    }
  ]
}
JSON


# --------- RUN + METADATA ----------
META_JSON="$SCRATCHDIR/icp_metadata.json"
echo "Spouštím PDAL ICP…" >> "$LOG_FILE"
singularity exec -B "$SCRATCHDIR":/data ./pdal.img pdal pipeline pdal_icp.json --metadata icp_metadata.json &>> "$LOG_FILE"


# --------- KOPIE VÝSTUPŮ ----------
cp "$SCRATCHDIR/icp.laz" "$RESULT_FILE" &>> "$LOG_FILE"
cp "$SCRATCHDIR/icp_metadata.json" $RESULT_METADATA &>> "$LOG_FILE"




# --------- ÚKLID ----------
clean_scratch
