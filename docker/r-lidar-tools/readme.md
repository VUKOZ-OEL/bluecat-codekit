### CMD

docker build -t martinkrucek/lidr.img:latest .
docker login
docker push martinkrucek/lidr.img:latest


### SH
qsub -I -l select=1:ncpus=6:mem=6gb:scratch_local=10gb -l walltime=2:00:00

cd $SCRATCHDIR
module add singul
singularity build lidr.img docker://martinkrucek/lidr.img:latest

cp /storage/plzen1/home/krucek/test_script.R $SCRATCHDIR
cp /storage/plzen1/home/krucek/test_script.R $SCRATCHDIR

cp storage/brno2/home/krucek/bluecat/singularity_img/lidr.img
cp /storage/xxx/test_script.R $SCRATCHDIR
singularity exec -B "$SCRATCHDIR:/data" lidr.img Rscript /data/lidr_img_test_script.R


## local docker
docker run --rm -v "%cd%:" martinkrucek/lidr.img:latest test_script.R

chgrp -R bluecat /storage/brno2/home/krucek/bluecat
chmod g+s /storage/brno2/home/krucek/bluecat

sync_with_group bluecat $SCRATCHDIR/lidr.img /storage/brno2/home/krucek/bluecat/lidr.img
sync_with_group bluecat  /storage/plzen1/home/krucek/.aws/credentials /storage/brno2/home/krucek/bluecat/.aws/credentials