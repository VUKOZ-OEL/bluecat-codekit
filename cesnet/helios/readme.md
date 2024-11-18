singularity exec -B $SCRATCHDIR/:/data ./lastools.img las2txt -i rudice_sample.laz -o data.xyz -parse xyz
singularity exec -B $SCRATCHDIR/:/data ./lastools.img txt2las -i data.xyz -o olas.laz

qsub -l select=1:ncpus=4:mem=24gb:scratch_local=150gb -l walltime=24:00:00 -- /storage/projects2/InterCOST/simulate.sh RN_4_N.laz als_RN_4_N.xml xyzloader_RN_4_N.xml /storage/projects2/InterCOST/simulations/RN

