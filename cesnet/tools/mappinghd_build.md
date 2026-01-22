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

qsub -I -l select=1:ncpus=12:mem=16gb:scratch_local=32gb -l walltime=00:30:00 -- /storage/plzen1/home/krucek/scripts/hdmap_mls_process.sh /storage/plzen1/home/krucek/data/continousScanning_0001.zip

/storage/plzen1/home/krucek/HDMapping/build/bin
dos2unix /storage/plzen1/home/krucek/scripts/hdmap_mls_process.sh
/storage/plzen1/home/krucek/scripts/hdmap_mls_process.sh /storage/plzen1/home/krucek/data/continousScanning_0001.zip

qsub -l select=1:ncpus=12:mem=16gb:scratch_local=32gb -l walltime=00:30:00 -- /storage/plzen1/home/krucek/scripts/hdmap_mls_process.sh /storage/plzen1/home/krucek/data/continousScanning_0001.zip