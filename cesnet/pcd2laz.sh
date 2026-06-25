# qsub -I -l select=1:ncpus=2:mem=2gb:scratch_local=5gb -l walltime=2:00:00
# @


SD=/storage/projects2/InterCOST/simulations/trees_working/RN_3_E
cp 8d78810620f7.pcd $SCRATCHDIR 
cd $SCRATCHDIR
module add singul/
cp /storage/projects2/InterCOST/singularity_img/pdal.img $SCRATCHDIR

singularity exec -B $SCRATCHDIR/:/data ./pdal.img pdal translate 8d78810620f7.pcd test.laz