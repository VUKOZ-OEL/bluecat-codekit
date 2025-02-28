
# Voxelize large las using lastools and tiling
## args: infile outfile voxel_resolution tile_size tile_buffer no_cores

#### Ask interactive job
```
qsub -I -l select=1:ncpus=6:mem=64gb:scratch_local=100gb -l walltime=2:00:00
qsub -I -l select=1:ncpus=12:mem=16gb:scratch_local=25gb -l walltime=2:00:00
qsub -I -l select=1:ncpus=2:mem=2gb:scratch_local=10gb -l walltime=1:00:00

qsub -I -l select=1:ncpus=24:mem=64gb:scratch_local=150gb -l walltime=12:00:00

```

### Test run
```
qsub -l select=1:ncpus=2:mem=4gb:scratch_local=15gb -l walltime=1:00:00 -- /storage/plzen1/home/krucek/voxelize.sh /storage/plzen1/home/krucek/data/RZ_rozek_SVV.laz /storage/plzen1/home/krucek/data/rz_voxelized/rz_13B_14.laz 0.02 1 0 2
```
### Commands
#### RZ
```


qsub -l select=1:ncpus=24:mem=64gb:scratch_local=150gb -l walltime=12:00:00 -- /storage/plzen1/home/krucek/voxelize.sh /storage/plzen1/home/krucek/data/rz/RZ12+12Bgeo.laz /storage/plzen1/home/krucek/data/rz_0005/rz_01.laz 0.005 1 0 24

qsub -l select=1:ncpus=24:mem=64gb:scratch_local=150gb -l walltime=12:00:00 -- /storage/plzen1/home/krucek/voxelize.sh /storage/plzen1/home/krucek/data/rz/RZ_240213.laz /storage/plzen1/home/krucek/data/rz_0005/rz_02.laz 0.005 1 0 24

qsub -l select=1:ncpus=24:mem=64gb:scratch_local=150gb -l walltime=12:00:00 -- /storage/plzen1/home/krucek/voxelize.sh /storage/plzen1/home/krucek/data/rz/RZ_jih_potok_k40.laz /storage/plzen1/home/krucek/data/rz_0005/rz_03.laz 0.005 1 0 24

qsub -l select=1:ncpus=24:mem=64gb:scratch_local=150gb -l walltime=12:00:00 -- /storage/plzen1/home/krucek/voxelize.sh /storage/plzen1/home/krucek/data/rz/RZ_jih_stred_kolik31.laz /storage/plzen1/home/krucek/data/rz_0005/rz_04.laz 0.005 1 0 24

qsub -l select=1:ncpus=24:mem=64gb:scratch_local=150gb -l walltime=12:00:00 -- /storage/plzen1/home/krucek/voxelize.sh /storage/plzen1/home/krucek/data/rz/RZ_roh_SSV.laz /storage/plzen1/home/krucek/data/rz_0005/rz_05.laz 0.005 1 0 24

qsub -l select=1:ncpus=24:mem=64gb:scratch_local=150gb -l walltime=12:00:00 -- /storage/plzen1/home/krucek/voxelize.sh /storage/plzen1/home/krucek/data/rz/RZ_roh_SZ_kolik23.laz /storage/plzen1/home/krucek/data/rz_0005/rz_06.laz 0.005 1 0 24

qsub -l select=1:ncpus=24:mem=64gb:scratch_local=150gb -l walltime=12:00:00 -- /storage/plzen1/home/krucek/voxelize.sh /storage/plzen1/home/krucek/data/rz/RZ_rozek_SVV.laz /storage/plzen1/home/krucek/data/rz_0005/rz_07.laz 0.005 1 0 24

qsub -l select=1:ncpus=24:mem=64gb:scratch_local=150gb -l walltime=12:00:00 -- /storage/plzen1/home/krucek/voxelize.sh /storage/plzen1/home/krucek/data/rz/rz240213B+14.laz /storage/plzen1/home/krucek/data/rz_0005/rz_08.laz 0.005 1 0 24


```
qsub -l select=1:ncpus=24:mem=128gb:scratch_local=300gb -l walltime=24:00:00 -- /storage/plzen1/home/krucek/scripts/pdal_voxelize2.sh /storage/plzen1/home/krucek/data/zh/ZH_02.laz /storage/plzen1/home/krucek/data/zh/UH_02_voxels.laz 0.005


#### ZH
qsub -l select=1:ncpus=24:mem=64gb:scratch_local=250gb -l walltime=12:00:00 -- /storage/plzen1/home/krucek/voxelize.sh /storage/plzen1/home/krucek/data/zh/ZakovaHora_240205_06_3.laz /storage/plzen1/home/krucek/data/zh_voxelized/zh_02.laz 0.005 1 0 24

```
qsub -l select=1:ncpus=24:mem=64gb:scratch_local=350gb -l walltime=12:00:00 -- /storage/plzen1/home/krucek/voxelize_2.sh /storage/plzen1/home/krucek/data/zh/02_tiles /storage/plzen1/home/krucek/data/zh_voxelized/zh_02.laz 0.005 1 0 24

qsub -l select=1:ncpus=24:mem=64gb:scratch_local=350gb -l walltime=12:00:00 -- /storage/plzen1/home/krucek/voxelize_2.sh /storage/plzen1/home/krucek/data/zh/04_tiles /storage/plzen1/home/krucek/data/zh_voxelized/zh_04.laz 0.005 1 0 24

qsub -l select=1:ncpus=24:mem=64gb:scratch_local=350gb -l walltime=12:00:00 -- /storage/plzen1/home/krucek/voxelize_2.sh /storage/plzen1/home/krucek/data/zh/05_tiles /storage/plzen1/home/krucek/data/zh_voxelized/zh_05.laz 0.005 1 0 24
```

qsub -l select=1:ncpus=24:mem=128gb:scratch_local=300gb -l walltime=24:00:00 -- /storage/plzen1/home/krucek/scripts/pdal_voxelize2.sh /storage/plzen1/home/krucek/data/zh/ZH_03.laz /storage/plzen1/home/krucek/data/zh/ZH_03_voxels.laz 0.005

qsub -l select=1:ncpus=24:mem=128gb:scratch_local=300gb -l walltime=24:00:00 -- /storage/plzen1/home/krucek/scripts/pdal_voxelize2.sh /storage/plzen1/home/krucek/data/zh/ZH_04.laz /storage/plzen1/home/krucek/data/zh/ZH_04_voxels.laz 0.005

qsub -l select=1:ncpus=24:mem=128gb:scratch_local=300gb -l walltime=24:00:00 -- /storage/plzen1/home/krucek/scripts/pdal_voxelize2.sh /storage/plzen1/home/krucek/data/zh/ZH_05.laz /storage/plzen1/home/krucek/data/zh/ZH_05_voxels.laz 0.005


qsub -l select=1:ncpus=24:mem=128gb:scratch_local=300gb -l walltime=24:00:00 -- /storage/plzen1/home/krucek/scripts/pdal_voxelize2.sh /storage/plzen1/home/krucek/data/zh/02_tiles/-636800_-1105100_1.laz /storage/plzen1/home/krucek/data/zh/tile_voxels.laz 0.005

qsub -l select=1:ncpus=8:mem=8gb:scratch_local=30gb -l walltime=2:00:00 -- /storage/plzen1/home/krucek/scripts/pdal_voxelize2.sh /storage/projects2/InterCOST/simulations/tiles/sl_6.laz /storage/projects2/InterCOST/simulations/tiles/sl_6_vox.laz 0.01
