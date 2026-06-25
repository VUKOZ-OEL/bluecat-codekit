qsub -I -l select=1:ncpus=2:mem=4gb:scratch_local=32gb -l walltime=01:30:00 -- /storage/plzen1/home/krucek/scripts/hdmap_process.sh /storage/plzen1/home/krucek/data/mandeye/30000110.zip


qsub -l select=1:ncpus=12:mem=32gb:scratch_local=32gb -l walltime=06:00:00 -- /storage/plzen1/home/krucek/scripts/hdmap_process_ua.sh /storage/plzen1/home/krucek/data/UA/tests/plot_12-2.zip /storage/plzen1/home/krucek/data/UA/tests/run_x.zip att1 att2 ...


qsub -l select=1:ncpus=12:mem=32gb:scratch_local=32gb \
     -l walltime=06:00:00 \
     -- /storage/plzen1/home/krucek/scripts/hdmap_process_ua.sh \
     /storage/plzen1/home/krucek/data/UA/tests/plot_12-2.zip \
     /storage/plzen1/home/krucek/data/UA/tests/run_01_current.zip \
     nr_iter=1000 \
     sliding_window=99999 \
     initial_points=999999 \
     nr_poses=20 \
     consistency=100 \
     maxdist=70 \
     outer=70

qsub -l select=1:ncpus=12:mem=32gb:scratch_local=32gb \
     -l walltime=08:00:00 \
     -- /storage/plzen1/home/krucek/scripts/hdmap_process_ua.sh \
     /storage/plzen1/home/krucek/data/UA/tests/plot_12-2.zip \
     /storage/plzen1/home/krucek/data/UA/tests/run_02_iter1500.zip \
     nr_iter=1500 \
     sliding_window=99999 \
     initial_points=999999 \
     nr_poses=20 \
     consistency=100 \
     maxdist=70 \
     outer=70

qsub -l select=1:ncpus=12:mem=32gb:scratch_local=32gb \
     -l walltime=10:00:00 \
     -- /storage/plzen1/home/krucek/scripts/hdmap_process_ua.sh \
     /storage/plzen1/home/krucek/data/UA/tests/plot_12-2.zip \
     /storage/plzen1/home/krucek/data/UA/tests/run_03_iter2500.zip \
     nr_iter=2500 \
     sliding_window=99999 \
     initial_points=999999 \
     nr_poses=20 \
     consistency=100 \
     maxdist=70 \
     outer=70

qsub -l select=1:ncpus=12:mem=32gb:scratch_local=32gb \
     -l walltime=08:00:00 \
     -- /storage/plzen1/home/krucek/scripts/hdmap_process_ua.sh \
     /storage/plzen1/home/krucek/data/UA/tests/plot_12-2.zip \
     /storage/plzen1/home/krucek/data/UA/tests/run_04_window3000.zip \
     nr_iter=1500 \
     sliding_window=3000 \
     initial_points=999999 \
     nr_poses=20 \
     consistency=100 \
     maxdist=70 \
     outer=70

qsub -l select=1:ncpus=12:mem=32gb:scratch_local=32gb \
     -l walltime=08:00:00 \
     -- /storage/plzen1/home/krucek/scripts/hdmap_process_ua.sh \
     /storage/plzen1/home/krucek/data/UA/tests/plot_12-2.zip \
     /storage/plzen1/home/krucek/data/UA/tests/run_05_window1500_poses50.zip \
     nr_iter=1500 \
     sliding_window=1500 \
     initial_points=999999 \
     nr_poses=50 \
     consistency=100 \
     maxdist=70 \
     outer=70

qsub -l select=1:ncpus=12:mem=32gb:scratch_local=32gb \
     -l walltime=08:00:00 \
     -- /storage/plzen1/home/krucek/scripts/hdmap_process_ua.sh \
     /storage/plzen1/home/krucek/data/UA/tests/plot_12-2.zip \
     /storage/plzen1/home/krucek/data/UA/tests/run_06_init100k.zip \
     nr_iter=1500 \
     sliding_window=3000 \
     initial_points=100000 \
     nr_poses=50 \
     consistency=100 \
     maxdist=70 \
     outer=70

qsub -l select=1:ncpus=12:mem=32gb:scratch_local=32gb \
     -l walltime=10:00:00 \
     -- /storage/plzen1/home/krucek/scripts/hdmap_process_ua.sh \
     /storage/plzen1/home/krucek/data/UA/tests/plot_12-2.zip \
     /storage/plzen1/home/krucek/data/UA/tests/run_07_dec003.zip \
     nr_iter=1500 \
     sliding_window=3000 \
     initial_points=999999 \
     nr_poses=50 \
     consistency=100 \
     maxdist=70 \
     outer=70 \
     decimation=0.003

qsub -l select=1:ncpus=12:mem=32gb:scratch_local=32gb \
     -l walltime=10:00:00 \
     -- /storage/plzen1/home/krucek/scripts/hdmap_process_ua.sh \
     /storage/plzen1/home/krucek/data/UA/tests/plot_12-2.zip \
     /storage/plzen1/home/krucek/data/UA/tests/run_08_robust.zip \
     nr_iter=1500 \
     sliding_window=3000 \
     initial_points=999999 \
     nr_poses=50 \
     consistency=100 \
     maxdist=70 \
     outer=70 \
     robust=true \
     robust_iter=40 \
     rigid_iter=60
