singularity exec -B $SCRATCHDIR/:/data ./lastools.img las2txt -i rudice_sample.laz -o data.xyz -parse xyz
singularity exec -B $SCRATCHDIR/:/data ./lastools.img txt2las -i data.xyz -o olas.laz

qsub -l select=1:ncpus=4:mem=24gb:scratch_local=150gb -l walltime=24:00:00 -- /storage/projects2/InterCOST/simulate.sh RN_4_N.laz als_RN_4_N.xml xyzloader_RN_4_N.xml /storage/projects2/InterCOST/simulations/RN


cd $SCRATCHDIR

INPUT_DATA=RN_4_N.laz
SURVEY_XML=als_RN_4_N_uniloader.xml
LOADER_XML=cloud_xyzloader.xml
DATADIR=/storage/projects2/InterCOST/simulations/rn_test
INPUT_DATA_XYZ=cloud.xyz



qsub -I -l select=1:ncpus=4:mem=16gb:scratch_local=25gb -l walltime=2:00:00

cd /storage/projects2/InterCOST/simulations/rn_test
./simulate_uniloader.sh RN_4_N.laz als_RN_4_N_uniloader.xml xyzloader_uni.xml /storage/projects2/InterCOST/simulations/rn_test

```
singularity exec -B $SCRATCHDIR/helios-plusplus-lin/output/:/data ./lastools.img txt2las -i *.xyz -olaz -odir data
```

qsub -I -l select=1:ncpus=4:mem=16gb:scratch_local=25gb -l walltime=1:00:00
cd /storage/projects2/InterCOST/simulations/rn_test
./simulate_uniloader.sh RN_4_N.laz als_RN_4_N_uniloader.xml cloud_xyzloader.xml /storage/projects2/InterCOST/simulations/rn_test

qsub -l select=1:ncpus=24:mem=64gb:scratch_local=125gb -l walltime=12:00:00 -- /storage/projects2/InterCOST/simulations/rn_test/simulate_uniloader.sh RN_4_N.laz als_RN_4_N_uniloader.xml cloud_xyzloader.xml /storage/projects2/InterCOST/simulations/rn_test

qsub -l select=1:ncpus=4:mem=64gb:scratch_local=12gb -l walltime=00:30:00 -- /storage/projects2/InterCOST/simulations/rn_test/simulate_uniloader.sh RN_4_N_nth999.laz als_RN_4_N_uniloader.xml cloud_xyzloader.xml /storage/projects2/InterCOST/simulations/rn_test