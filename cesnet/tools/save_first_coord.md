# Salajka ULS 2024 leaf-off

qsub -l select=1:ncpus=2:mem=4gb:scratch_local=100gb -l walltime=01:00:00 -- /storage/plzen1/home/krucek/scripts/save_first_coord.sh /storage/plzen1/home/krucek/data/salajka/sl_2024_off_clip_3035.laz

qsub -l select=1:ncpus=2:mem=4gb:scratch_local=100gb -l walltime=01:00:00 -- /storage/plzen1/home/krucek/scripts/save_first_coord.sh /storage/plzen1/home/krucek/data/salajka/sl_1.laz
qsub -l select=1:ncpus=2:mem=4gb:scratch_local=100gb -l walltime=01:00:00 -- /storage/plzen1/home/krucek/scripts/save_first_coord.sh /storage/plzen1/home/krucek/data/salajka/sl_2.laz
qsub -l select=1:ncpus=2:mem=4gb:scratch_local=100gb -l walltime=01:00:00 -- /storage/plzen1/home/krucek/scripts/save_first_coord.sh /storage/plzen1/home/krucek/data/salajka/sl_3.laz
qsub -l select=1:ncpus=2:mem=4gb:scratch_local=100gb -l walltime=01:00:00 -- /storage/plzen1/home/krucek/scripts/save_first_coord.sh /storage/plzen1/home/krucek/data/salajka/sl_4.laz
