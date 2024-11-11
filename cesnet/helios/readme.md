singularity exec -B $SCRATCHDIR/:/data ./lastools.img las2txt -i rudice_sample.laz -o data.xyz -parse xyz
singularity exec -B $SCRATCHDIR/:/data ./lastools.img txt2las -i data.xyz -o olas.laz



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