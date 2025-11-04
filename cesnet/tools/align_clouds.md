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

qsub -l select=1:ncpus=24:mem=128gb:scratch_local=150gb -l walltime=2:00:00 -- /storage/plzen1/home/krucek/scripts/align_clouds.sh /storage/plzen1/home/krucek/data/velka_ples/VP_2012_TLS_translated000.laz /storage/plzen1/home/krucek/data/velka_ples/VP_nth10.laz

qsub -I -l select=1:ncpus=24:mem=128gb:scratch_local=250gb -l walltime=2:00:00 -- /storage/plzen1/home/krucek/scripts/align_clouds_decimate.sh /storage/plzen1/home/krucek/data/velka_ples/VP_2012_TLS_translated000.laz /storage/plzen1/home/krucek/data/velka_ples/VP_2025_ULS.laz 10

qsub -l select=1:ncpus=36:mem=256gb:scratch_local=300gb -l walltime=4:00:00 -- /storage/plzen1/home/krucek/scripts/align_clouds.sh /storage/plzen1/home/krucek/data/VP/VUK__22__VelkaPles__NA__ULS.laz /storage/plzen1/home/krucek/data/VP/vp_mls_vox_5mm.laz

qsub -l select=1:ncpus=36:mem=256gb:scratch_local=300gb -l walltime=4:00:00 -- /storage/plzen1/home/krucek/scripts/align_clouds_decimate.sh /storage/plzen1/home/krucek/data/VP/VUK__22__VelkaPles__NA__ULS.laz /storage/plzen1/home/krucek/data/VP/vp_mls_vox_5mm.laz 4



```
qsub -l select=1:ncpus=24:mem=32gb:scratch_local=25gb -l walltime=2:00:00 -- /storage/plzen1/home/krucek/scripts/align_clouds.sh /storage/plzen1/home/krucek/acuveg/loff/Pokojna_3.laz /storage/plzen1/home/krucek/acuveg/lon_2025/Pokojna_3_LON_2025.laz

qsub -l select=1:ncpus=24:mem=32gb:scratch_local=25gb -l walltime=2:00:00 -- /storage/plzen1/home/krucek/scripts/align_clouds.sh /storage/plzen1/home/krucek/acuveg/loff/Pokojna_1.laz /storage/plzen1/home/krucek/acuveg/lon_2025/Pokojna_1_LON_2025.laz

qsub -l select=1:ncpus=24:mem=32gb:scratch_local=25gb -l walltime=2:00:00 -- /storage/plzen1/home/krucek/scripts/align_clouds.sh /storage/plzen1/home/krucek/acuveg/loff/Chvaletice_loff.laz /storage/plzen1/home/krucek/acuveg/lon_2025/Chvaletice_LON_2025.laz

```