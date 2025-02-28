# first run 
```
qsub -l select=1:ncpus=24:mem=64gb:scratch_local=250 -l walltime=12:00:00 -- /storage/plzen1/home/krucek/scripts/segment.sh 01_clipped.laz /storage/plzen1/home/krucek/data/rz_0005 true 0.02 true
qsub -l select=1:ncpus=24:mem=64gb:scratch_local=250 -l walltime=12:00:00 -- /storage/plzen1/home/krucek/scripts/segment.sh 02_clipped.laz /storage/plzen1/home/krucek/data/rz_0005 true 0.03 true
qsub -l select=1:ncpus=24:mem=64gb:scratch_local=250 -l walltime=12:00:00 -- /storage/plzen1/home/krucek/scripts/segment.sh 03_clipped.laz /storage/plzen1/home/krucek/data/rz_0005 true 0.02 true
qsub -l select=1:ncpus=24:mem=64gb:scratch_local=250 -l walltime=12:00:00 -- /storage/plzen1/home/krucek/scripts/segment.sh 04_clipped.laz /storage/plzen1/home/krucek/data/rz_0005 true 0.02 true
qsub -l select=1:ncpus=24:mem=64gb:scratch_local=250 -l walltime=12:00:00 -- /storage/plzen1/home/krucek/scripts/segment.sh 05_clipped.laz /storage/plzen1/home/krucek/data/rz_0005 true 0.02 true
qsub -l select=1:ncpus=24:mem=64gb:scratch_local=250 -l walltime=12:00:00 -- /storage/plzen1/home/krucek/scripts/segment.sh 06_clipped.laz /storage/plzen1/home/krucek/data/rz_0005 true 0.02 true
qsub -l select=1:ncpus=24:mem=64gb:scratch_local=250 -l walltime=12:00:00 -- /storage/plzen1/home/krucek/scripts/segment.sh 07_clipped.laz /storage/plzen1/home/krucek/data/rz_0005 true 0.02 true
qsub -l select=1:ncpus=24:mem=64gb:scratch_local=250 -l walltime=12:00:00 -- /storage/plzen1/home/krucek/scripts/segment.sh 08_clipped.laz /storage/plzen1/home/krucek/data/rz_0005 true 0.02 true
```

```
qsub -l select=1:ncpus=34:mem=164gb:scratch_local=350 -l walltime=24:00:00 -- /storage/plzen1/home/krucek/scripts/segment.sh 01_clipped.laz /storage/plzen1/home/krucek/data/rz_0005 true 0.02 true

qsub -l select=1:ncpus=34:mem=164gb:scratch_local=350 -l walltime=24:00:00 -- /storage/plzen1/home/krucek/scripts/segment.sh 03_clipped.laz /storage/plzen1/home/krucek/data/rz_0005 true 0.02 true

qsub -l select=1:ncpus=34:mem=164gb:scratch_local=350 -l walltime=24:00:00 -- /storage/plzen1/home/krucek/scripts/segment.sh 08_clipped.laz /storage/plzen1/home/krucek/data/rz_0005 true 0.02 true
```


