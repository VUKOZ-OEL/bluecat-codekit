
# Voxelize large las using lastools and tiling
## args: infile outfile voxel_resolution tile_size tile_buffer no_cores

#### Ask interactive job
```
qsub -I -l select=1:ncpus=6:mem=64gb:scratch_local=100gb -l walltime=4:00:00
qsub -I -l select=1:ncpus=12:mem=16gb:scratch_local=25gb -l walltime=2:00:00
qsub -I -l select=1:ncpus=2:mem=2gb:scratch_local=10gb -l walltime=1:00:00

```

### Test run
```
qsub -l select=1:ncpus=8:mem=64gb:scratch_local=150gb -l walltime=2:00:00 -- /storage/plzen1/home/krucek/voxelize.sh /storage/plzen1/home/krucek/data/rz/rz240213B+14.laz /storage/plzen1/home/krucek/data/rz_voxelized/rz_13B_14.laz 0.02 1 0 8
```


