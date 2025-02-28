# Align file B on file A
# Skript očekává dva vstupní soubory (plná cesta) jako parametry.



### Použití: qsub -l select=1:ncpus=24:mem=32gb:scratch_local=25gb -l walltime=2:00:00 file/A.laz file/B.laz

qsub -I -l select=1:ncpus=24:mem=32gb:scratch_local=25gb -l walltime=2:00:00


```
qsub -l select=1:ncpus=24:mem=32gb:scratch_local=25gb -l walltime=2:00:00 -- /storage/plzen1/home/krucek/scripts/align_clouds.sh /storage/plzen1/home/krucek/acuveg/loff/Brezinka_1.laz /storage/plzen1/home/krucek/acuveg/lon/Brezinka_1.laz
qsub -l select=1:ncpus=24:mem=32gb:scratch_local=25gb -l walltime=2:00:00 -- /storage/plzen1/home/krucek/scripts/align_clouds.sh /storage/plzen1/home/krucek/acuveg/loff/Brezinka_2.laz /storage/plzen1/home/krucek/acuveg/lon/Brezinka_2.laz
qsub -l select=1:ncpus=24:mem=32gb:scratch_local=25gb -l walltime=2:00:00 -- /storage/plzen1/home/krucek/scripts/align_clouds.sh /storage/plzen1/home/krucek/acuveg/loff/Brezinka_3.laz /storage/plzen1/home/krucek/acuveg/lon/Brezinka_3.laz

qsub -l select=1:ncpus=24:mem=32gb:scratch_local=25gb -l walltime=2:00:00 -- /storage/plzen1/home/krucek/scripts/align_clouds.sh /storage/plzen1/home/krucek/acuveg/loff/Klepacov_1.laz /storage/plzen1/home/krucek/acuveg/lon/Klepacov_1.laz
qsub -l select=1:ncpus=24:mem=32gb:scratch_local=25gb -l walltime=2:00:00 -- /storage/plzen1/home/krucek/scripts/align_clouds.sh /storage/plzen1/home/krucek/acuveg/loff/Klepacov_2.laz /storage/plzen1/home/krucek/acuveg/lon/Klepacov_2.laz

qsub -l select=1:ncpus=24:mem=32gb:scratch_local=25gb -l walltime=2:00:00 -- /storage/plzen1/home/krucek/scripts/align_clouds.sh /storage/plzen1/home/krucek/acuveg/loff/Pokojna_2.laz /storage/plzen1/home/krucek/acuveg/lon/Pokojna_2.laz
qsub -l select=1:ncpus=24:mem=32gb:scratch_local=25gb -l walltime=2:00:00 -- /storage/plzen1/home/krucek/scripts/align_clouds.sh /storage/plzen1/home/krucek/acuveg/loff/Pokojna_3.laz /storage/plzen1/home/krucek/acuveg/lon/Pokojna_3.laz
```



A="/storage/plzen1/home/krucek/acuveg/loff/Brezinka_1.laz"
B="/storage/plzen1/home/krucek/acuveg/lon/Brezinka_1.laz"