qsub -l select=1:ncpus=12:mem=32gb:scratch_local=32gb -l walltime=02:00:00 -- /storage/plzen1/home/krucek/scripts/hdmap_process.sh /storage/plzen1/home/krucek/data/plot_12-2_hdmapping_rawslam.zip
