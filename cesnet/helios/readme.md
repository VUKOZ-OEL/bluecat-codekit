singularity exec -B $SCRATCHDIR/:/data ./lastools.img las2txt -i rudice_sample.laz -o data.xyz -parse xyz
singularity exec -B $SCRATCHDIR/:/data ./lastools.img txt2las -i data.xyz -o olas.laz