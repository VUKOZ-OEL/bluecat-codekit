## code used to run on cesnet infrastructure

#### Ask interactive job
```
qsub -I -l select=1:ncpus=6:mem=8gb:scratch_local=10gb -l walltime=4:00:00
```

#### Build docker images for singularity
```
singularity build raycloudtools.img docker://tdevereux/raycloudtools:latest
singularity build r-lidar-tools.img docker://martinkrucek/r-lidar-tools:latest
singularity build pdal.img docker://pdal/pdal:latest
singularity build lastools.img docker://pointscene/lastools:latest
singularity build cloudcompare.img docker://tswetnam/cloudcompare:latest

singularity build heliospp.img docker://heliospp/heliospp-py38
singularity build heliospp.img docker://heliospp/heliospp-py39
```

#### Run SH files
```
qsub -l select=1:ncpus=24:mem=64gb:scratch_local=150gb -l walltime=24:00:00 /storage/plzen1/home/krucek/gs-lcr/001/ray_klepacov1_vox001.sh
qsub -l select=1:ncpus=24:mem=64gb:scratch_local=150gb -l walltime=24:00:00 /storage/plzen1/home/krucek/gs-lcr/001/ray_klepacov2_vox001.sh
qsub -l select=1:ncpus=24:mem=64gb:scratch_local=150gb -l walltime=24:00:00 /storage/plzen1/home/krucek/gs-lcr/001/ray_rudice_vox001.sh
```


qsub -l select=1:ncpus=1:mem=1gb:scratch_local=11gb -l walltime=1:00:00 /storage/plzen1/home/krucek/InterCOST/sh/helios_master.sh aaa.las asdasd.xml /storage/plzen1/home/krucek/InterCOST/sh
