# Build MappingHD for mandeye scanners data processing

might need: *module unload python* first
use cmake version >4.0 /storage/plzen1/home/krucek/cmake/cmake-4.2.0-linux-x86_64

```
  module purge
  module add git/2.35.2-gcc-10.2.1-ys3caml
  module add python/3.9.12-gcc-10.2.1-rg2lpmk
  module add opencv/4.5.4-gcc-10.2.1-663hk5g
  
  module add cmake/3.23.1-gcc-10.2.1-gxvea6z
  
  git clone https://github.com/MapsHD/HDMapping.git
  cd HDMapping
  mkdir build
  git submodule init
  git submodule update --recursive
  cd build
  /storage/plzen1/home/krucek/cmake/cmake-4.2.0-linux-x86_64/bin/cmake -DCMAKE_BUILD_TYPE=Release -DPYBIND=ON -DPYTHON_EXECUTABLE=$(which python3) ..
  
  make -j2 lidar_odometry_py core_py multi_view_tls_registration_py
  
  make -j
```



# run 

qsub -l select=1:ncpus=12:mem=16gb:scratch_local=32gb -l walltime=02:30:00 -- /storage/plzen1/home/krucek/scripts/hdmap_mls_process_2.sh /storage/plzen1/home/krucek/data/continousScanning_0006.zip

/storage/plzen1/home/krucek/HDMapping/build/bin
dos2unix /storage/plzen1/home/krucek/scripts/hdmap_mls_process.sh
/storage/plzen1/home/krucek/scripts/hdmap_mls_process.sh /storage/plzen1/home/krucek/data/continousScanning_0001.zip

qsub -l select=1:ncpus=12:mem=32gb:scratch_local=32gb -l walltime=02:00:00 -- /storage/plzen1/home/krucek/scripts/hdmap_process.sh /storage/plzen1/home/krucek/data/continousScanning_0001.zip

for f in /storage/plzen1/home/krucek/data/UA/plot_11/*.zip; do
    qsub -l select=1:ncpus=24:mem=64gb:scratch_local=100gb \
         -l walltime=06:00:00 \
         -- /storage/plzen1/home/krucek/scripts/hdmap_process.sh "$f"
done


qsub -l select=1:ncpus=16:mem=32gb:scratch_local=64gb -l walltime=04:30:00 -- /storage/plzen1/home/krucek/scripts/hdmap_process_step1.sh /storage/plzen1/home/krucek/data/UA/others/plot_12-1.zip
qsub -l select=1:ncpus=16:mem=32gb:scratch_local=64gb -l walltime=04:30:00 -- /storage/plzen1/home/krucek/scripts/hdmap_process_step1.sh /storage/plzen1/home/krucek/data/UA/others/plot_12-2.zip

qsub -l select=1:ncpus=16:mem=32gb:scratch_local=64gb -l walltime=04:30:00 -- /storage/plzen1/home/krucek/scripts/hdmap_process_step1.sh /storage/plzen1/home/krucek/data/UA/plot_11/p_1.zip

for f in /storage/plzen1/home/krucek/data/UA/rotated_11/*.zip; do
    out="${f%.zip}_v1.zip"
    
    qsub -l select=1:ncpus=24:mem=64gb:scratch_local=100gb \
         -l walltime=24:00:00 \
         -- /storage/plzen1/home/krucek/scripts/hdmap_process.sh "$f" "$out" decimation=0.01 threshold_initial_points=99999 num_constistency_iter=250
done

for f in /storage/plzen1/home/krucek/data/UA/rotated_11/*.zip; do
   
    qsub -l select=1:ncpus=24:mem=64gb:scratch_local=100gb \
         -l walltime=08:00:00 \
         -- /storage/plzen1/home/krucek/scripts/hdmap_process_step1.sh "$f" 
done


qsub -l select=1:ncpus=32:mem=32gb:scratch_local=150gb -l walltime=24:00:00 -- /storage/plzen1/home/krucek/scripts/hdmap_process.sh /storage/plzen1/home/krucek/data/UA/others/rakhivski_dil_derotated.zip
qsub -l select=1:ncpus=32:mem=32gb:scratch_local=150gb -l walltime=24:00:00 -- /storage/plzen1/home/krucek/scripts/hdmap_process.sh /storage/plzen1/home/krucek/data/UA/others/kamen_derotated.zip
qsub -l select=1:ncpus=32:mem=32gb:scratch_local=150gb -l walltime=24:00:00 -- /storage/plzen1/home/krucek/scripts/hdmap_process.sh /storage/plzen1/home/krucek/data/UA/others/lysa_derotated.zip
qsub -l select=1:ncpus=32:mem=32gb:scratch_local=150gb -l walltime=24:00:00 -- /storage/plzen1/home/krucek/scripts/hdmap_process.sh /storage/plzen1/home/krucek/data/UA/others/plot_13-1_derotated.zip
qsub -l select=1:ncpus=32:mem=32gb:scratch_local=150gb -l walltime=24:00:00 -- /storage/plzen1/home/krucek/scripts/hdmap_process.sh /storage/plzen1/home/krucek/data/UA/others/plot_13-2_derotated.zip
qsub -l select=1:ncpus=32:mem=32gb:scratch_local=150gb -l walltime=24:00:00 -- /storage/plzen1/home/krucek/scripts/hdmap_process.sh /storage/plzen1/home/krucek/data/UA/others/plot_12-1_derotated.zip
qsub -l select=1:ncpus=16:mem=16gb:scratch_local=25gb -l walltime=04:00:00 -- /storage/plzen1/home/krucek/scripts/hdmap_process.sh /storage/plzen1/home/krucek/data/UA/others/plot_12-2_derotated.zip

qsub -l select=1:ncpus=32:mem=128gb:scratch_local=150gb -l walltime=24:00:00 -- /storage/plzen1/home/krucek/scripts/hdmap_process_step1.sh /storage/plzen1/home/krucek/data/UA/others/rakhivski_dil_derotated.zip
qsub -l select=1:ncpus=32:mem=128gb:scratch_local=150gb -l walltime=24:00:00 -- /storage/plzen1/home/krucek/scripts/hdmap_process_step1.sh /storage/plzen1/home/krucek/data/UA/others/kamen_derotated.zip
qsub -l select=1:ncpus=32:mem=32gb:scratch_local=150gb -l walltime=24:00:00 -- /storage/plzen1/home/krucek/scripts/hdmap_process_step1.sh /storage/plzen1/home/krucek/data/UA/others/lysa_derotated.zip
qsub -l select=1:ncpus=32:mem=32gb:scratch_local=150gb -l walltime=24:00:00 -- /storage/plzen1/home/krucek/scripts/hdmap_process_step1.sh /storage/plzen1/home/krucek/data/UA/others/plot_13-1_derotated.zip
qsub -l select=1:ncpus=32:mem=32gb:scratch_local=150gb -l walltime=24:00:00 -- /storage/plzen1/home/krucek/scripts/hdmap_process_step1.sh /storage/plzen1/home/krucek/data/UA/others/plot_13-2_derotated.zip
qsub -l select=1:ncpus=32:mem=32gb:scratch_local=150gb -l walltime=24:00:00 -- /storage/plzen1/home/krucek/scripts/hdmap_process_step1.sh /storage/plzen1/home/krucek/data/UA/others/plot_12-1_derotated.zip
qsub -l select=1:ncpus=16:mem=16gb:scratch_local=25gb -l walltime=04:00:00 -- /storage/plzen1/home/krucek/scripts/hdmap_process_step1.sh /storage/plzen1/home/krucek/data/UA/others/plot_12-2_derotated.zip


for f in /storage/plzen1/home/krucek/data/UA/rotated_11/*.zip; do
    out="${f%.zip}_v1.zip"
    
    qsub -l select=1:ncpus=24:mem=64gb:scratch_local=100gb \
         -l walltime=24:00:00 \
         -- /storage/plzen1/home/krucek/scripts/hdmapping_full_out.sh "$f" "$out" decimation=0.01 threshold_initial_points=99999 num_constistency_iter=250
done
