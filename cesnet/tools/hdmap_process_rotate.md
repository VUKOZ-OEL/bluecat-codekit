qsub -l select=1:ncpus=12:mem=32gb:scratch_local=32gb -l walltime=06:00:00 -- /storage/plzen1/home/krucek/scripts/hdmap_process_rotate.sh /storage/plzen1/home/krucek/data/UA/tests/plot_12-2.zip
