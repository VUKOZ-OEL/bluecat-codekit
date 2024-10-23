cp lastools2.img /storage/plzen1/home/krucek/singularity_img/lastools.img
cp cloudcompare.img /storage/plzen1/home/krucek/singularity_img

cp /storage/plzen1/home/krucek/raycloud/Salajka_hover_uls_002_clip.laz $SCRATCHDIR/pts.laz


singularity build lastools.img docker://pointscene/lastools:latest

singularity exec -B $SCRATCHDIR/:/data ./cloudcompare.img "-SILENT -O pts.laz -SS SPATIAL 0.1 -C_EXPORT_FMT LAS -SAVE_CLOUDS"

singularity shell -B $SCRATCHDIR/:/data ./cloudcompare.img vglrun CloudCompare

singularity exec -B $SCRATCHDIR/:/data ./lastools2.img las2las -i pts.laz -o vox.laz -step 0.1



source /storage/plzen1/home/krucek/test_dir/master.sh rudice_sample /storage/plzen1/home/krucek/test_dir

script -q -c "source /storage/plzen1/home/krucek/test_dir/master.sh rudice_sample.laz /storage/plzen1/home/krucek/test_dir"