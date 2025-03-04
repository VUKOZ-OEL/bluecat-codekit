#!/bin/bash

# Nastavení proměnných
export SOURCE_FILE=$1  # První argument je vstupní soubor (e.g., cloud.laz)
export RESULT_FILE=$2  # Výstupní soubor

echo "$(date) node ready"
echo "$SCRATCHDIR" 

# Přesun do scratch adresáře
cd $SCRATCHDIR
cp $SOURCE_FILE $SCRATCHDIR/in.laz

# Přidání modulů
module add singul/ 
cp /storage/projects2/InterCOST/singularity_img/pdal.img $SCRATCHDIR

# Najdeme nejnižší bod na Z a průměr XY pro centrování
singularity exec -B $SCRATCHDIR:/data ./pdal.img pdal info /data/in.laz --metadata > metadata.json

mkdir -p bin
cd bin
wget -O jq https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64
chmod +x jq
export PATH=$SCRATCHDIR/bin:$PATH
cd ..

# Extrahujeme min hodnoty Z
MIN_Z=$(jq '.metadata.minz' metadata.json)

# Vypočítáme střed XY
MID_X=$(jq -r '.metadata.minx + ((.metadata.maxx - .metadata.minx) / 2)' metadata.json)
MID_Y=$(jq -r '.metadata.miny + ((.metadata.maxy - .metadata.miny) / 2)' metadata.json)

T_X=$(( -1 * MID_X ))
MID_Y=$(( -1 * MID_Y ))
MIN_Z=$(( -1 * MIN_Z ))

# Vytvoříme PDAL pipeline pro centrování
cat <<EOF > pdal_translate.json
{
  "pipeline": [
    { "type": "readers.las", "filename": "/data/in.laz" },
    { "type": "filters.transformation",
      "matrix":"1 0 0 $T_X 0 1 0 $T_Y 0 0 1 $T_Z 0 0 0 1"
    },
    { "type": "writers.las", "filename": "/data/centered.laz", "dataformat_id": 1, "minor_version": 2 }
  ]
}
EOF

# Spustíme PDAL pipeline pro transformaci souřadnic
singularity exec -B $SCRATCHDIR:/data ./pdal.img pdal pipeline /data/pdal_translate.json 

# Kopírování výsledku zpět
cp $SCRATCHDIR/centered.laz $RESULT_FILE

clean_scratch
