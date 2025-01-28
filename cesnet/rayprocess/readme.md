# setup sublime: https://www.geeksforgeeks.org/how-to-use-terminal-in-sublime-text-editor/



## Example command
```
qsub -l select=1:ncpus=6:mem=24gb:scratch_local=25gb -l walltime=12:00:00 -- /storage/projects2/InterCOST/segment.sh SOURCE_DATA DATADIR VOXELIZE VOXEL_RES ADD_TIME
```

# set variables
```
export SOURCE_DATA=rudice_sample.laz
export DATADIR=/storage/plzen1/home/krucek/test_dir
export VOXELIZE=${3:-true}
export VOXEL_RES=${4:-0.01}
export ADD_TIME=${5:-true}
```
