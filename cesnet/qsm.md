
qsub -l select=1:ncpus=12:mem=48gb:scratch_local=25gb -l walltime=00:10:00 /storage/projects2/InterCOST/trees/qsm_bc_trees.sh


./run_qsm_batches.sh /storage/projects2/InterCOST/trees/test_trees/las

qsub -- /storage/projects2/InterCOST/trees/qsm_on_scratch.sh /storage/projects2/InterCOST/trees/test_trees/las/00123bc33a55.las /storage/projects2/InterCOST/trees/test_trees/las/00201cdf1f80.las