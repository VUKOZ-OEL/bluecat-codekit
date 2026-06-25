qsub -l select=1:ncpus=12:mem=32gb:scratch_local=32gb -l walltime=01:00:00 -- /storage/plzen1/home/krucek/scripts/filter_noise.sh /storage/plzen1/home/krucek/data/mandeye/30000110_leveled.zip
