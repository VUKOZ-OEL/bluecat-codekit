#!/bin/bash
# Použití: qsub -I -l select=1:ncpus=8:mem=64gb:scratch_local=50gb -l walltime=4:00:00
# Odstranění MTA šumu z ALS dat (body pod terénem a nad povrchem porostu)
# Skript očekává jeden vstupní soubor (plná cesta) jako parametr.
#
# Postup:
#   1. filters.elm      - detekce nízkých bodů pod terénem (Extended Local Minimum)
#   2. filters.outlier  - statistické odlehlé body
#   3. filters.smrf     - klasifikace terénu (ignoruje již označený šum)
#   4. filters.hag_nn   - výška nad terénem; vše pod HAG_MIN a nad HAG_MAX -> class 7
#
# Výstup: *_classified.laz (šum jako class 7, nic nesmazáno - pro vizuální kontrolu)
#         *_clean.laz      (šum odstraněn)

# ===================== PARAMETRY (upravte dle území) =====================
HAG_MIN="-1.0"     # tolerance pod terénem [m] - vše níže = šum
HAG_MAX="45.0"     # max. smysluplná výška vegetace/objektů [m] - vše výše = šum
ELM_CELL="20.0"    # velikost buňky pro ELM [m]
ELM_THRESHOLD="1.0" # výškový skok pro detekci nízkého bodu [m]
OUTLIER_MEAN_K="8"        # počet sousedů pro statistický filtr
OUTLIER_MULTIPLIER="2.5"  # násobek směrodatné odchylky
# SMRF - parametry vhodné pro lesní/členité území
SMRF_SLOPE="0.2"
SMRF_WINDOW="18"
SMRF_THRESHOLD="0.45"
SMRF_SCALAR="1.2"
# =========================================================================

# Kontrola vstupních parametrů
if [ "$#" -ne 1 ]; then
    echo "Použití: $0 cesta/k_souboru.laz"
    exit 1
fi

IN="$1"
IN_NAME=$(basename "$IN")
OUT_CLASSIFIED="${IN_NAME%.laz}_classified.laz"
OUT_CLEAN="${IN_NAME%.laz}_clean.laz"

# Kontrola existence vstupního souboru
if [ ! -f "$IN" ]; then
    echo "Chyba: Vstupní soubor neexistuje."
    exit 1
fi

# Kopírování vstupního souboru do scratch prostoru
cp "$IN" "$SCRATCHDIR/input.laz"

# Nahrání modulů
module add singul/

# Kopírování Singularity kontejneru do scratch prostoru
cp /storage/brno2/home/krucek/bluecat/singularity_img/pdal.img "$SCRATCHDIR"

# Přechod do scratch adresáře
cd "$SCRATCHDIR" || exit 1

# Vytvoření PDAL pipeline
cat <<EOF > pdal_denoise.json
{
  "pipeline": [
    {
      "type": "readers.las",
      "filename": "/data/input.laz"
    },
    {
      "comment": "Reset klasifikace - puvodni MTA-postizene tridy mohou byt nespolehlive",
      "type": "filters.assign",
      "value": "Classification = 0"
    },
    {
      "comment": "Krok 1: nizke body pod terenem -> class 7",
      "type": "filters.elm",
      "cell": ${ELM_CELL},
      "threshold": ${ELM_THRESHOLD},
      "class": 7
    },
    {
      "comment": "Krok 2: statisticke odlehle body -> class 7",
      "type": "filters.outlier",
      "method": "statistical",
      "mean_k": ${OUTLIER_MEAN_K},
      "multiplier": ${OUTLIER_MULTIPLIER},
      "class": 7
    },
    {
      "comment": "Krok 3: klasifikace terenu, sum se ignoruje",
      "type": "filters.smrf",
      "ignore": "Classification[7:7]",
      "slope": ${SMRF_SLOPE},
      "window": ${SMRF_WINDOW},
      "threshold": ${SMRF_THRESHOLD},
      "scalar": ${SMRF_SCALAR}
    },
    {
      "comment": "Krok 4: vyska nad terenem (nejblizsi ground body)",
      "type": "filters.hag_nn",
      "count": 4,
      "allow_extrapolation": true
    },
    {
      "comment": "Vse pod terenem a nad porostem -> class 7",
      "type": "filters.assign",
      "value": [
        "Classification = 7 WHERE HeightAboveGround < ${HAG_MIN}",
        "Classification = 7 WHERE HeightAboveGround > ${HAG_MAX}"
      ]
    },
    {
      "comment": "Vystup 1: kompletni mracno s klasifikovanym sumem",
      "type": "writers.las",
      "compression": true,
      "extra_dims": "HeightAboveGround=float32",
      "filename": "/data/${OUT_CLASSIFIED}"
    },
    {
      "comment": "Odstraneni sumu",
      "type": "filters.range",
      "limits": "Classification![7:7]"
    },
    {
      "comment": "Vystup 2: ciste mracno",
      "type": "writers.las",
      "compression": true,
      "filename": "/data/${OUT_CLEAN}"
    }
  ]
}
EOF

# Spuštění PDAL pipeline
singularity exec -B "$SCRATCHDIR":/data ./pdal.img pdal pipeline /data/pdal_denoise.json

# Kontrola, že výstupy vznikly
if [ ! -f "$SCRATCHDIR/$OUT_CLEAN" ]; then
    echo "Chyba: PDAL pipeline selhala, výstup nevznikl."
    exit 1
fi

# Statistika - kolik bodů bylo odstraněno
echo "--- Statistika ---"
singularity exec -B "$SCRATCHDIR":/data ./pdal.img pdal info --summary "/data/input.laz" | grep -i "num_points"
singularity exec -B "$SCRATCHDIR":/data ./pdal.img pdal info --summary "/data/$OUT_CLEAN" | grep -i "num_points"

# Kopírování výsledných souborů zpět do původního umístění
cp "$SCRATCHDIR/$OUT_CLASSIFIED" "$(dirname "$IN")/$OUT_CLASSIFIED"
cp "$SCRATCHDIR/$OUT_CLEAN" "$(dirname "$IN")/$OUT_CLEAN"

echo "Hotovo."
echo "Klasifikovaný výstup: $(dirname "$IN")/$OUT_CLASSIFIED"
echo "Čistý výstup:         $(dirname "$IN")/$OUT_CLEAN"
clean_scratch
