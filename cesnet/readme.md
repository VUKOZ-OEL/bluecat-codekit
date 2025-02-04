## > https://profile.e-infra.cz/profile/
## > https://perun.einfra.cesnet.cz/


## code used to run on cesnet infrastructure

#### Ask interactive job
```
qsub -I -l select=1:ncpus=6:mem=4gb:scratch_local=10gb -l walltime=4:00:00
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
qsub -l select=1:ncpus=24:mem=64gb:scratch_local=150gb -l walltime=24:00:00 -- /storage/plzen1/home/krucek/segment.sh SLP_Klepacov1_clip_vox001_gpst.laz /storage/plzen1/home/krucek/gs-lcr/001 false 0.01 true
qsub -l select=1:ncpus=24:mem=64gb:scratch_local=150gb -l walltime=24:00:00 -- /storage/plzen1/home/krucek/segment.sh SLP_Klepacov2_clip_vox001_gpst.laz /storage/plzen1/home/krucek/gs-lcr/001 false 0.01 true
qsub -l select=1:ncpus=24:mem=64gb:scratch_local=150gb -l walltime=24:00:00 -- /storage/plzen1/home/krucek/segment.sh SLP_Rudice_clip_vox001_gpst.laz false /storage/plzen1/home/krucek/gs-lcr/001 false 0.01 true
qsub -l select=1:ncpus=4:mem=6gb:scratch_local=15gb -l walltime=1:00:00 -- /storage/plzen1/home/krucek/test_dir/master.sh rudice_sample.laz /storage/plzen1/home/krucek/test_dir true 0.01 true
```


```
qsub -l select=1:ncpus=24:mem=64gb:scratch_local=150gb -l walltime=12:00:00 -- /storage/plzen1/home/krucek/scripts/segment.sh 01_clipped.laz /storage/plzen1/home/krucek/data/rz_0005 true 0.01 true

qsub -l select=1:ncpus=24:mem=64gb:scratch_local=150gb -l walltime=12:00:00 -- /storage/plzen1/home/krucek/scripts/segment.sh 02_clipped.laz /storage/plzen1/home/krucek/data/rz_0005 true 0.01 true
qsub -l select=1:ncpus=24:mem=64gb:scratch_local=150gb -l walltime=12:00:00 -- /storage/plzen1/home/krucek/scripts/segment.sh 03_clipped.laz /storage/plzen1/home/krucek/data/rz_0005 true 0.01 true
qsub -l select=1:ncpus=24:mem=64gb:scratch_local=150gb -l walltime=12:00:00 -- /storage/plzen1/home/krucek/scripts/segment.sh 04_clipped.laz /storage/plzen1/home/krucek/data/rz_0005 true 0.01 true
qsub -l select=1:ncpus=24:mem=64gb:scratch_local=150gb -l walltime=12:00:00 -- /storage/plzen1/home/krucek/scripts/segment.sh 05_clipped.laz /storage/plzen1/home/krucek/data/rz_0005 true 0.01 true
qsub -l select=1:ncpus=24:mem=64gb:scratch_local=150gb -l walltime=12:00:00 -- /storage/plzen1/home/krucek/scripts/segment.sh 06_clipped.laz /storage/plzen1/home/krucek/data/rz_0005 true 0.01 true
qsub -l select=1:ncpus=24:mem=64gb:scratch_local=150gb -l walltime=12:00:00 -- /storage/plzen1/home/krucek/scripts/segment.sh 07_clipped.laz /storage/plzen1/home/krucek/data/rz_0005 true 0.01 true
qsub -l select=1:ncpus=24:mem=64gb:scratch_local=150gb -l walltime=12:00:00 -- /storage/plzen1/home/krucek/scripts/segment.sh 08_clipped.laz /storage/plzen1/home/krucek/data/rz_0005 true 0.01 true

<<<<<<< Updated upstream
qsub -l select=1:ncpus=8:mem=6gb:scratch_local=10gb -l walltime=2:00:00 -- /storage/plzen1/home/krucek/test_helios/helios_master2.sh DN21_pine_without_vox_cut10x10.xyz test_als.xml DN21_plot_xyzloader.xml /storage/plzen1/home/krucek/test_helios


qsub -l select=1:ncpus=8:mem=6gb:scratch_local=10gb -l walltime=2:00:05 -- /storage/plzen1/home/krucek/test_dir/master.sh rudice_sample.laz /storage/plzen1/home/krucek/test_dir

qsub -l select=1:ncpus=16:mem=32gb:scratch_local=20gb -l walltime=12:00:00 -- /storage/projects2/InterCOST/segment.sh DN13_voxels_0_01_cut50x50.laz /storage/projects2/InterCOST/segmentation


qsub -l select=1:ncpus=16:mem=32gb:scratch_local=200gb -l walltime=12:00:00 -- /storage/plzen1/home/krucek/WFDP/segment.sh WFDP_q5.laz /storage/plzen1/home/krucek/WFDP

-m u:janoutova:rwx /storage/projects2/InterCOST

qsub -l select=1:ncpus=16:mem=128gb:scratch_local=200gb -l walltime=24:00:00 -- /storage/plzen1/home/krucek/WFDP/segment.sh WFDP_q5.laz /storage/plzen1/home/krucek/WFDP

qsub -l select=1:ncpus=6:mem=24gb:scratch_local=25gb -l walltime=12:00:00 -- /storage/projects2/InterCOST/segment.sh WFDP_2021_q2_001.laz /storage/projects2/InterCOST/segmentation/raw_data true 0.01 true

uments\GitHub\VUKOZ-OEL\3d-forest\out\build\x64-Debug\src\apps\3dforest

docker run --rm -v C:\Users\krucek\Documents\razula\rz_01:/data pdal/pdal pdal info --metadata --count 1 /segments/laz/cloud_segmented_-1.laz > output.txt
docker run --rm -v C:\Users\krucek\Documents\razula\rz_01\segments\laz:/data pdal/pdal pdal info -p 0 /data/cloud_segmented_2.laz > /data/output.txt

save_first_coord.sh /storage/plzen1/home/krucek/data/rz_voxelized

cd $SCRATCHDIR

cp /storage/plzen1/home/krucek/data/rz_voxelized/rz_01.laz $SCRATCHDIR

qsub -l select=1:ncpus=2:mem=4gb:scratch_local=10gb -l walltime=1:00:00 -- /storage/plzen1/home/krucek/save_first_coord.sh /storage/plzen1/home/krucek/data/rz_voxelized/rz_06.laz
qsub -l select=1:ncpus=2:mem=4gb:scratch_local=10gb -l walltime=1:00:00 -- /storage/plzen1/home/krucek/save_first_coord.sh /storage/plzen1/home/krucek/data/rz_voxelized/rz_07.laz
qsub -l select=1:ncpus=2:mem=4gb:scratch_local=10gb -l walltime=1:00:00 -- /storage/plzen1/home/krucek/save_first_coord.sh /storage/plzen1/home/krucek/data/rz_voxelized/rz_08.laz

export FILE_IN=/storage/plzen1/home/krucek/data/rz_voxelized/rz_03.laz

./save_first_coord.sh /storage/plzen1/home/krucek/data/rz_voxelized/rz_04.laz
=======
>>>>>>> Stashed changes
