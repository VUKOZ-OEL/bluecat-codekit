#!/bin/bash
# Skript pro oříznutí LAZ souboru pomocí PDAL a polygonu (shapefile)

# Ověření počtu argumentů (minimálně 3)
if [ "$#" -lt 3 ]; then
  echo "Usage: $0 input.laz clippoly.shp output.laz"
  exit 1
fi

# Nastavení proměnných z argumentů
export SOURCE_FILE=$1    # vstupní LAZ soubor
export CLIP_POLY=$2      # geojson s polygonem
export RESULT_FILE=$3    # výstupní LAZ soubor

export LOG_FILE="$RESULT_FILE.log"
echo "$(date) – spuštění skriptu" >> $LOG_FILE
echo "Scratch adresář: $SCRATCHDIR" >> $LOG_FILE

# Přesun do scratch adresáře
cd $SCRATCHDIR || { echo "Nelze vstoupit do $SCRATCHDIR"; exit 1; }
echo "Pracovní adresář: $(pwd)" >> $LOG_FILE

# Zkopírování vstupních souborů do scratch
cp $SOURCE_FILE $SCRATCHDIR/in.laz &>> $LOG_FILE
cp $CLIP_POLY $SCRATCHDIR/clippoly.GeoJSON &>> $LOG_FILE
# copy shapefile

wget -O jq https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64
chmod +x jq

# Načtení modulu Singularity a kopie PDAL obrazu do scratch (případně upravte dle vašeho prostředí)
module add singul/ &>> $LOG_FILE
cp /storage/plzen1/home/krucek/singularity_img/pdal.img $SCRATCHDIR &>> $LOG_FILE


POLY_GEOJSON=$(./jq -c '.features[0].geometry' clippoly.GeoJSON)
# Vytvoření PDAL pipeline – načte in.laz, aplikuje crop pomocí polygonu načteného ze souboru clippoly.shp a uloží výsledek do output.laz
cat <<EOF > pdal_pipeline.json
{
  "pipeline": [
    {
      "type": "readers.las",
      "filename": "in.laz"
    },
    {
      "type": "filters.crop",
      "polygon": $POLY_GEOJSON
    },
    {
      "type": "writers.las",
      "dataformat_id": 1,
      "minor_version": 2,
      "filename": "output.laz"
    }
  ]
}
EOF

# Spuštění PDAL pipeline pomocí Singularity; díky volbě -B je celý obsah scratch adresáře namapován do /data uvnitř kontejneru
singularity exec -B $SCRATCHDIR/:/data ./pdal.img pdal pipeline /data/pdal_pipeline.json

# Přesunutí výsledného souboru do cílové lokace
cp output.laz $RESULT_FILE &>> $LOG_FILE

echo "$(date) – skript dokončen" >> $LOG_FILE
clean_scratch
