## Salajka ULS leaf off 2024
qsub -l select=1:ncpus=48:mem=256gb:scratch_local=500gb -l walltime=24:00:00 -- /storage/plzen1/home/krucek/scripts/segment.sh sl_2024_off_clip_3035.laz /storage/plzen1/home/krucek/data/salajka true 0.02 true 
qsub -l select=1:ncpus=48:mem=128gb:scratch_local=200gb -l walltime=24:00:00 -- /storage/plzen1/home/krucek/scripts/segment.sh sl_1.laz /storage/plzen1/home/krucek/data/salajka true 0.02 true 
qsub -l select=1:ncpus=48:mem=128gb:scratch_local=200gb -l walltime=24:00:00 -- /storage/plzen1/home/krucek/scripts/segment.sh sl_2.laz /storage/plzen1/home/krucek/data/salajka true 0.02 true 
qsub -l select=1:ncpus=48:mem=128gb:scratch_local=200gb -l walltime=24:00:00 -- /storage/plzen1/home/krucek/scripts/segment.sh sl_3.laz /storage/plzen1/home/krucek/data/salajka true 0.02 true 
qsub -l select=1:ncpus=48:mem=128gb:scratch_local=200gb -l walltime=24:00:00 -- /storage/plzen1/home/krucek/scripts/segment.sh sl_4.laz /storage/plzen1/home/krucek/data/salajka true 0.02 true

## Zofin TLS 2022

qsub -l select=1:ncpus=48:mem=128gb:scratch_local=200gb -l walltime=24:00:00 -- /storage/plzen1/home/krucek/scripts/segment.sh ZF_2022_q33.laz /storage/plzen1/home/krucek/data/ZF true 0.02 true
qsub -l select=1:ncpus=48:mem=128gb:scratch_local=200gb -l walltime=24:00:00 -- /storage/plzen1/home/krucek/scripts/segment.sh ZF_2022_q34.laz /storage/plzen1/home/krucek/data/ZF true 0.02 true
