qsub -l select=1:ncpus=12:mem=128gb:scratch_local=200gb -l walltime=6:00:00 -- /storage/plzen1/home/krucek/scripts/pdal_voxelize_firstPt.sh /storage/plzen1/home/krucek/data/VP/vp.laz /storage/plzen1/home/krucek/data/VP/vp_vox_5mm.laz

qsub -I -l select=1:ncpus=12:mem=16gb:scratch_local=20gb -l walltime=6:00:00 -- /storage/plzen1/home/krucek/scripts/pdal_voxelize_mean.sh /storage/plzen1/home/krucek/data/sumava_npo_max2m/B2.las /storage/plzen1/home/krucek/data/B2_vox_mean.laz 10

qsub -l select=1:ncpus=12:mem=16gb:scratch_local=20gb -l walltime=6:00:00 -- /storage/plzen1/home/krucek/scripts/pdal_voxelize_firstPt.sh /storage/plzen1/home/krucek/data/sumava_npo_max2m/B2.las /storage/plzen1/home/krucek/data/B2_vox_first.laz 10

qsub -l select=1:ncpus=12:mem=16gb:scratch_local=20gb -l walltime=6:00:00 -- /storage/plzen1/home/krucek/scripts/pdal_voxelize_center.sh /storage/plzen1/home/krucek/data/sumava_npo_max2m/B2.las /storage/plzen1/home/krucek/data/B2_vox_center.laz 10

qsub -I -l select=1:ncpus=12:mem=16gb:scratch_local=20gb -l walltime=6:00:00 -- /storage/plzen1/home/krucek/scripts/pdal_voxelize_voxelgrid.sh /storage/plzen1/home/krucek/data/sumava_npo_max2m/B2.las /storage/plzen1/home/krucek/data/B2_vox_grid.laz 10






https://wildcardproject.sharepoint.com/:x:/r/sites/WildcardProject-WP3-VUKOZ/Shared%20Documents/WP3%20-%20VUKOZ/Data/NEW%20data%20-%20since%20Jan%202024/New_chronosequence_Metadata/Site_characteristics_WILDCARD.xlsx?d=w3c45a952d34b4a738b496d9a86aa5506&csf=1&web=1&e=smhCdj

qsub -I -l select=1:ncpus=12:mem=16gb:scratch_local=20gb -l walltime=1:00:00

export SOURCE_FILE="/storage/plzen1/home/krucek/data/sumava_npo_max2m/B2.las"

export VOXEL_SIZE=10

singularity exec -B $SCRATCHDIR/:/data ./cloudcompare.img CloudCompare -SILENT -O /data/in.laz -C_EXPORT_FMT LAS -SS SPATIAL "$VOXEL_SIZE" -SAVE_CLOUDS FILE "/data/cloud.laz"
