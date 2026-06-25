singularity exec -B $SCRATCHDIR/:/data ./lastools.img las2txt -i rudice_sample.laz -o data.xyz -parse xyz
singularity exec -B $SCRATCHDIR/:/data ./lastools.img txt2las -i data.xyz -o olas.laz

qsub -l select=1:ncpus=8:mem=24gb:scratch_local=150gb -l walltime=24:00:00 -- /storage/projects2/InterCOST/simulate.sh RN_4_N.laz als_RN_4_N.xml xyzloader_RN_4_N.xml /storage/projects2/InterCOST/simulations/RN




singularity exec -B $SCRATCHDIR/:/data ./raycloudtools.img raywrap segments/cloud_segmented_320.ply downwards 5.0
cp segments/cloud_segmented_320_mesh.ply /storage/projects2/InterCOST/segmentation/downwards_5.ply

singularity exec -B $SCRATCHDIR/:/data ./raycloudtools.img raywrap segments/cloud_segmented_320.ply inwards 5.0
cp segments/cloud_segmented_320_mesh.ply /storage/projects2/InterCOST/segmentation/inwards_5.ply

singularity exec -B $SCRATCHDIR/:/data ./raycloudtools.img raywrap segments/cloud_segmented_320.ply inwards 1.0
cp segments/cloud_segmented_320_mesh.ply /storage/projects2/InterCOST/segmentation/inwards_1.ply

singularity exec -B $SCRATCHDIR/:/data ./raycloudtools.img raywrap segments/cloud_segmented_320.ply outwards 5.0
cp segments/cloud_segmented_320_mesh.ply /storage/projects2/InterCOST/segmentation/outwards_5.ply

singularity exec -B $SCRATCHDIR/:/data ./raycloudtools.img raywrap segments/cloud_segmented_320.ply outwards 1.0
cp segments/cloud_segmented_320_mesh.ply /storage/projects2/InterCOST/segmentation/outwards_1.ply

cp segments/cloud_segmented_320.ply /storage/projects2/InterCOST/segmentation/cloud_segmented_320.ply

qsub -l select=1:ncpus=16:mem=34gb:scratch_local=50gb -l walltime=6:00:00 -- /storage/projects2/InterCOST/simulations/vox001_centered_00min/simulate_.sh RN_3_N_001_c00.laz als_.xml xyzloader_.xml /storage/projects2/InterCOST/simulations/vox001_centered_00min

qsub -I -l select=1:ncpus=2:mem=2gb:scratch_local=5gb -l walltime=2:00:00

INPUT_DATA=RN_4_N_nth999_c00.laz
SURVEY_XML=als_.xml
LOADER_XML=xyzloader_.xml
DATADIR=/storage/projects2/InterCOST/simulations/vox001_centered_00min

