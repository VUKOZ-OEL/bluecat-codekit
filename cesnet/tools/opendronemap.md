module add singul

### build
singularity build odm.img docker://opendronemap/odm:latest

singularity build lidr.img docker://martinkrucek/lidr:latest

 ```
docker run -it --rm \
    -v "$(pwd)/images:/code/images" \
    -v "$(pwd)/odm_orthophoto:/code/odm_orthophoto" \
    -v "$(pwd)/odm_texturing:/code/odm_texturing" \
    opendronemap/opendronemap
```


singularity exec -B "$SCRATCHDIR:/data" odm.img odm --project-path /data
singularity exec -B "$SCRATCHDIR:/data" odm.img /code/run.sh --project-path /data myproject





 ```
INPUT="/storage/plzen1/home/krucek/tis/petrova_skala.zip"
cp /storage/plzen1/home/krucek/singularity_img/odm.img $SCRATCHDIR
cp $INPUT $SCRATCHDIR

cd $SCRATCHDIR
unzip petrova_skala.zip

module add singul

mkdir petrova_skala/images
cp petrova_skala/001/*.tif petrova_skala/images/

singularity exec -B "$SCRATCHDIR:/data" odm.img /code/run.sh --project-path /data petrova_skala

zip -r reults.zip petrova_skala
cp results.zip /storage/plzen1/home/krucek/tis/

 ```

 qsub -I -l select=1:ncpus=24:mem=128gb:scratch_local=250gb -l walltime=1:00:00 -- /storage/plzen1/home/krucek/scripts/multispectral2mosaic.sh /storage/plzen1/home/krucek/tis/Spalena.zip