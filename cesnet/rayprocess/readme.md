# setup sublime: https://www.geeksforgeeks.org/how-to-use-terminal-in-sublime-text-editor/
alt + 1
@


## Example command
```
qsub -l select=1:ncpus=16:mem=64gb:scratch_local=25gb -l walltime=12:00:00 -- /storage/projects2/InterCOST/segment.sh SOURCE_DATA DATADIR VOXELIZE VOXEL_RES ADD_TIME
```

# set variables
```
export SOURCE_DATA=rudice_sample.laz
export DATADIR=/storage/plzen1/home/krucek/test_dir
export VOXELIZE=${3:-true}
export VOXEL_RES=${4:-0.01}
export ADD_TIME=${5:-true}
```


```
qsub -l select=1:ncpus=16:mem=64gb:scratch_local=125gb -l walltime=12:00:00 -- /storage/projects2/InterCOST/segment.sh rz_01.laz /storage/plzen1/home/krucek/data/rz_voxelized false 0.02 true
qsub -l select=1:ncpus=16:mem=64gb:scratch_local=125gb -l walltime=12:00:00 -- /storage/projects2/InterCOST/segment.sh rz_03.laz /storage/plzen1/home/krucek/data/rz_voxelized false 0.02 true
qsub -l select=1:ncpus=16:mem=64gb:scratch_local=125gb -l walltime=12:00:00 -- /storage/projects2/InterCOST/segment.sh rz_04.laz /storage/plzen1/home/krucek/data/rz_voxelized false 0.02 true
qsub -l select=1:ncpus=16:mem=64gb:scratch_local=125gb -l walltime=12:00:00 -- /storage/projects2/InterCOST/segment.sh rz_05.laz /storage/plzen1/home/krucek/data/rz_voxelized false 0.02 true
qsub -l select=1:ncpus=16:mem=64gb:scratch_local=125gb -l walltime=12:00:00 -- /storage/projects2/InterCOST/segment.sh rz_06.laz /storage/plzen1/home/krucek/data/rz_voxelized false 0.02 true
qsub -l select=1:ncpus=16:mem=64gb:scratch_local=125gb -l walltime=12:00:00 -- /storage/projects2/InterCOST/segment.sh rz_07.laz /storage/plzen1/home/krucek/data/rz_voxelized false 0.02 true
qsub -l select=1:ncpus=16:mem=64gb:scratch_local=125gb -l walltime=12:00:00 -- /storage/projects2/InterCOST/segment.sh rz_08.laz /storage/plzen1/home/krucek/data/rz_voxelized false 0.02 true
qsub -l select=1:ncpus=16:mem=64gb:scratch_local=125gb -l walltime=12:00:00 -- /storage/projects2/InterCOST/segment.sh rz_02.laz /storage/plzen1/home/krucek/data/rz_voxelized false 0.02 true
```

```
qsub -l select=1:ncpus=16:mem=64gb:scratch_local=50gb -l walltime=12:00:00 -- /storage/plzen1/home/krucek/segment.sh zh_02.laz /storage/plzen1/home/krucek/data/zh_voxelized true 0.02 true

```