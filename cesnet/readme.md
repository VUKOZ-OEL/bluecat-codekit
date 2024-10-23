## code used to run on cesnet infrastructure

#### Ask interactive job
```
qsub -I -l select=1:ncpus=6:mem=8gb:scratch_local=10gb -l walltime=2:00:00
```

#### Build docker images for singularity
```
singularity build raycloudtools.img docker://tdevereux/raycloudtools:latest
singularity build r-lidar-tools.img docker://martinkrucek/r-lidar-tools:latest
singularity build pdal.img docker://pdal/pdal:latest
singularity build lastools.img docker://pointscene/lastools:latest
singularity build cloudcompare.img docker://tswetnam/cloudcompare:latest
```

#### Run SH files
```
qsub -l select=1:ncpus=24:mem=64gb:scratch_local=150gb -l walltime=24:00:00 /storage/plzen1/home/krucek/gs-lcr/001/ray_klepacov1_vox001.sh
qsub -l select=1:ncpus=24:mem=64gb:scratch_local=150gb -l walltime=24:00:00 /storage/plzen1/home/krucek/gs-lcr/001/ray_klepacov2_vox001.sh
qsub -l select=1:ncpus=24:mem=64gb:scratch_local=150gb -l walltime=24:00:00 /storage/plzen1/home/krucek/gs-lcr/001/ray_rudice_vox001.sh
```


source /storage/plzen1/home/krucek/test_dir/master.sh rudice_sample /storage/plzen1/home/krucek/test_dir