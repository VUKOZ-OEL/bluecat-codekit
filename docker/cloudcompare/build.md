### CMD

docker build -t martinkrucek/cloudcompare.img:latest .
docker login
docker push martinkrucek/cloudcompare.img:latest


### SH
qsub -I -l select=1:ncpus=6:mem=6gb:scratch_local=10gb -l walltime=2:00:00

cd $SCRATCHDIR
module add singul
singularity build cloudcompare.img docker://martinkrucek/cloudcompare.img:latest


