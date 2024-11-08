## code used to run on cesnet infrastructure

#### Ask interactive job
```
qsub -I -l select=1:ncpus=6:mem=64gb:scratch_local=100gb -l walltime=4:00:00
qsub -I -l select=1:ncpus=12:mem=16gb:scratch_local=25gb -l walltime=2:00:00
qsub -I -l select=1:ncpus=2:mem=2gb:scratch_local=10gb -l walltime=1:00:00

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

qsub -l select=1:ncpus=4:mem=6gb:scratch_local=15gb -l walltime=1:00:00 -- /storage/plzen1/home/krucek/test_dir/master.sh rudice_sample.laz /storage/plzen1/home/krucek/test_dir true 0.01 true
```




qsub -l select=1:ncpus=8:mem=6gb:scratch_local=10gb -l walltime=2:00:00 -- /storage/plzen1/home/krucek/test_helios/helios_master2.sh DN21_pine_without_vox_cut10x10.xyz test_als.xml DN21_plot_xyzloader.xml /storage/plzen1/home/krucek/test_helios


qsub -l select=1:ncpus=8:mem=6gb:scratch_local=10gb -l walltime=2:00:05 -- /storage/plzen1/home/krucek/test_dir/master.sh rudice_sample.laz /storage/plzen1/home/krucek/test_dir

qsub -l select=1:ncpus=16:mem=32gb:scratch_local=20gb -l walltime=12:00:00 -- /storage/projects2/InterCOST/segment.sh DN13_voxels_0_01_cut50x50.laz /storage/projects2/InterCOST/segmentation

qsub -l select=1:ncpus=16:mem=32gb:scratch_local=20gb -l walltime=12:00:00 -- /storage/plzen1/home/krucek/WFDP/segment.sh WFDP_q5.laz /storage/plzen1/home/krucek/WFDP