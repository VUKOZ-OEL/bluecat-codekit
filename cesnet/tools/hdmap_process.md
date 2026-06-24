qsub -I -l select=1:ncpus=2:mem=4gb:scratch_local=32gb -l walltime=01:30:00 -- /storage/plzen1/home/krucek/scripts/hdmap_process.sh /storage/plzen1/home/krucek/data/mandeye/30000110.zip
