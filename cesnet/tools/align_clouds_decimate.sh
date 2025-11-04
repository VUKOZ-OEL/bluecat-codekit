#!/bin/bash
# Použití: qsub -I -l select=1:ncpus=24:mem=32gb:scratch_local=25gb -l walltime=2:00:00
# Skript očekává dva vstupní soubory (plná cesta) jako parametry.
# Align file B on file A

# Kontrola vstupních parametrů
if [ "$#" -ne 2 ]; then
    echo "Použití: $0 cesta/k_souboru_A.laz cesta/k_souboru_B.laz"
    exit 1
fi

A="$1"
B="$2"
decimation_level=$3

# Získání názvů souborů bez cesty
A_NAME=$(basename "$A")
B_NAME=$(basename "$B")

# Výstupní název pro zarovnaný soubor
B_ALIGNED="${B_NAME%.laz}_aligned.laz"

# Kontrola existence vstupních souborů
if [ ! -f "$A" ] || [ ! -f "$B" ]; then
    echo "Chyba: Jeden nebo oba vstupní soubory neexistují."
    exit 1
fi

# Kopírování vstupních souborů do scratch prostoru
cp "$A" "$SCRATCHDIR/c1.laz"
cp "$B" "$SCRATCHDIR/c2.laz"

# Nahrání modulů
module add singul/

# Kopírování Singularity kontejnerů do scratch prostoru
cp /storage/plzen1/home/krucek/singularity_img/raycloudtools.img "$SCRATCHDIR"
cp /storage/projects2/InterCOST/singularity_img/pdal.img "$SCRATCHDIR"

# Přechod do scratch adresáře
cd "$SCRATCHDIR" || exit 1

# Vytvoření PDAL pipeline pro c1
cat <<EOF > pdal_pipeline_c1.json
{
  "pipeline": [
    {
      "type": "readers.las",
      "filename": "c1.laz"
    },
    {
      "type": "filters.ferry",
      "dimensions": "X=>GpsTime"
    },
    {
      "type": "writers.las",
      "dataformat_id": 1,
      "minor_version": 2,
      "filename": "c1_gpst.laz"
    }
  ]
}
EOF

# Vytvoření PDAL pipeline pro c2
cat <<EOF > pdal_pipeline_c2.json
{
  "pipeline": [
    {
      "type": "readers.las",
      "filename": "c2.laz"
    },
    {
      "type": "filters.ferry",
      "dimensions": "X=>GpsTime"
    },
    {
      "type": "writers.las",
      "dataformat_id": 1,
      "minor_version": 2,
      "filename": "c2_gpst.laz"
    }
  ]
}
EOF

# Spuštění PDAL pipeline
singularity exec -B "$SCRATCHDIR":/data ./pdal.img pdal pipeline /data/pdal_pipeline_c1.json
singularity exec -B "$SCRATCHDIR":/data ./pdal.img pdal pipeline /data/pdal_pipeline_c2.json

# Import do ray cloud formátu
singularity exec -B "$SCRATCHDIR":/data ./raycloudtools.img rayimport c1_gpst.laz ray 0,0,-10
singularity exec -B "$SCRATCHDIR":/data ./raycloudtools.img rayimport c2_gpst.laz ray 0,0,-10

singularity exec -B $SCRATCHDIR:/data ./raycloudtools.img raydecimate c1_gpst.ply $decimation_level rays
singularity exec -B $SCRATCHDIR:/data ./raycloudtools.img raydecimate c2_gpst.ply $decimation_level rays

# Zarovnání c2 na c1
singularity exec -B "$SCRATCHDIR":/data ./raycloudtools.img rayalign c2_gpst_decimated.ply c1_gpst_decimated.ply

# Export zarovnaného souboru
singularity exec -B "$SCRATCHDIR":/data ./raycloudtools.img rayexport c2_gpst_decimated_aligned.ply "$B_ALIGNED" traj.txt

# Kopírování výsledného souboru zpět do původního umístění
cp "$SCRATCHDIR/$B_ALIGNED" "$(dirname "$B")/$B_ALIGNED"

echo "Zarovnání dokončeno. Výstupní soubor: $(dirname "$B")/$B_ALIGNED"
clean_scratch
