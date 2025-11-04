## > https://profile.e-infra.cz/profile/
## > https://perun.einfra.cesnet.cz/

@

## code used to run on cesnet infrastructure

#### Ask interactive job
```
qsub -I -l select=1:ncpus=4:mem=16gb:scratch_local=100gb -l walltime=3:00:00
qsub -I -l select=1:ncpus=12:mem=64gb:scratch_local=25gb -l walltime=4:00:00
qsub -I -l select=1:ncpus=6:mem=6gb:scratch_local=10gb -l walltime=2:00:00

```

#### Build docker images for singularity
```
singularity build raycloudtools.img docker://tdevereux/raycloudtools:latest
singularity build r-lidar-tools.img docker://martinkrucek/r-lidar-tools:latest
singularity build pdal.img docker://pdal/pdal:latest
singularity build lastools.img docker://pointscene/lastools:latest
singularity build cloudcompare.img docker://tswetnam/cloudcompare:latest



```

#### Run SH files
```
qsub -l select=1:ncpus=24:mem=64gb:scratch_local=150gb -l walltime=24:00:00 -- /storage/plzen1/home/krucek/segment.sh SLP_Klepacov1_clip_vox001_gpst.laz /storage/plzen1/home/krucek/gs-lcr/001 false 0.02 true
qsub -l select=1:ncpus=24:mem=64gb:scratch_local=150gb -l walltime=24:00:00 -- /storage/plzen1/home/krucek/segment.sh SLP_Klepacov2_clip_vox001_gpst.laz /storage/plzen1/home/krucek/gs-lcr/001 false 0.02 true
qsub -l select=1:ncpus=24:mem=64gb:scratch_local=150gb -l walltime=24:00:00 -- /storage/plzen1/home/krucek/segment.sh SLP_Rudice_clip_vox001_gpst.laz false /storage/plzen1/home/krucek/gs-lcr/001 false 0.02 true
qsub -l select=1:ncpus=4:mem=6gb:scratch_local=15gb -l walltime=1:00:00 -- /storage/plzen1/home/krucek/test_dir/master.sh rudice_sample.laz /storage/plzen1/home/krucek/test_dir true 0.02 true
```


```
qsub -l select=1:ncpus=24:mem=64gb:scratch_local=250 -l walltime=12:00:00 -- /storage/plzen1/home/krucek/scripts/segment.sh 01_clipped.laz /storage/plzen1/home/krucek/data/rz_0005 true 0.02 true
qsub -l select=1:ncpus=24:mem=64gb:scratch_local=250 -l walltime=12:00:00 -- /storage/plzen1/home/krucek/scripts/segment.sh 02_clipped.laz /storage/plzen1/home/krucek/data/rz_0005 true 0.03 true
qsub -l select=1:ncpus=24:mem=64gb:scratch_local=250 -l walltime=12:00:00 -- /storage/plzen1/home/krucek/scripts/segment.sh 03_clipped.laz /storage/plzen1/home/krucek/data/rz_0005 true 0.02 true
qsub -l select=1:ncpus=24:mem=64gb:scratch_local=250 -l walltime=12:00:00 -- /storage/plzen1/home/krucek/scripts/segment.sh 04_clipped.laz /storage/plzen1/home/krucek/data/rz_0005 true 0.02 true
qsub -l select=1:ncpus=24:mem=64gb:scratch_local=250 -l walltime=12:00:00 -- /storage/plzen1/home/krucek/scripts/segment.sh 05_clipped.laz /storage/plzen1/home/krucek/data/rz_0005 true 0.02 true
qsub -l select=1:ncpus=24:mem=64gb:scratch_local=250 -l walltime=12:00:00 -- /storage/plzen1/home/krucek/scripts/segment.sh 06_clipped.laz /storage/plzen1/home/krucek/data/rz_0005 true 0.02 true
qsub -l select=1:ncpus=24:mem=64gb:scratch_local=250 -l walltime=12:00:00 -- /storage/plzen1/home/krucek/scripts/segment.sh 07_clipped.laz /storage/plzen1/home/krucek/data/rz_0005 true 0.02 true
qsub -l select=1:ncpus=24:mem=64gb:scratch_local=250 -l walltime=12:00:00 -- /storage/plzen1/home/krucek/scripts/segment.sh 08_clipped.laz /storage/plzen1/home/krucek/data/rz_0005 true 0.02 true
```
qsub -l select=1:ncpus=8:mem=6gb:scratch_local=10gb -l walltime=2:00:00 -- /storage/plzen1/home/krucek/test_helios/helios_master2.sh DN21_pine_without_vox_cut10x10.xyz test_als.xml DN21_plot_xyzloader.xml /storage/plzen1/home/krucek/test_helios


qsub -l select=1:ncpus=8:mem=6gb:scratch_local=10gb -l walltime=2:00:05 -- /storage/plzen1/home/krucek/test_dir/master.sh rudice_sample.laz /storage/plzen1/home/krucek/test_dir

qsub -l select=1:ncpus=16:mem=32gb:scratch_local=20gb -l walltime=12:00:00 -- /storage/projects2/InterCOST/segment.sh DN13_voxels_0_01_cut50x50.laz /storage/projects2/InterCOST/segmentation


qsub -l select=1:ncpus=16:mem=32gb:scratch_local=200gb -l walltime=12:00:00 -- /storage/plzen1/home/krucek/WFDP/segment.sh WFDP_q5.laz /storage/plzen1/home/krucek/WFDP

-m u:janoutova:rwx /storage/projects2/InterCOST
chmod -R 777 /storage/projects2/InterCOST
chmod -R ugo+rwx /storage/projects2/InterCOST

qsub -l select=1:ncpus=16:mem=128gb:scratch_local=200gb -l walltime=24:00:00 -- /storage/plzen1/home/krucek/WFDP/segment.sh WFDP_q5.laz /storage/plzen1/home/krucek/WFDP

qsub -l select=1:ncpus=6:mem=24gb:scratch_local=25gb -l walltime=12:00:00 -- /storage/projects2/InterCOST/segment.sh WFDP_2021_q2_001.laz /storage/projects2/InterCOST/segmentation/raw_data true 0.02 true



qsub -l select=1:ncpus=2:mem=4gb:scratch_local=10gb -l walltime=1:00:00 -- /storage/plzen1/home/krucek/save_first_coord.sh /storage/plzen1/home/krucek/data/rz_voxelized/rz_06.laz
qsub -l select=1:ncpus=2:mem=4gb:scratch_local=10gb -l walltime=1:00:00 -- /storage/plzen1/home/krucek/save_first_coord.sh /storage/plzen1/home/krucek/data/rz_voxelized/rz_07.laz
qsub -l select=1:ncpus=2:mem=4gb:scratch_local=10gb -l walltime=1:00:00 -- /storage/plzen1/home/krucek/save_first_coord.sh /storage/plzen1/home/krucek/data/rz_voxelized/rz_08.laz

export LD_LIBRARY_PATH=/storage/plzen1/home/krucek/pkgs/jq/:$LD_LIBRARY_PATH
export LD_LIBRARY_PATH=/storage/plzen1/home/krucek/pkgs/jq/usr/:$LD_LIBRARY_PATH
export PATH=/storage/plzen1/home/krucek/pkgs/jq/usr/bin/:$PATH



matlab -r "run('/storage/projects2/InterCOST/trees/qsm_test_trees.m'); exit"

qsub -l select=1:ncpus=6:mem=6gb:scratch_local=10gb -l walltime=1:00:00 /storage/projects2/InterCOST/trees/qsm_test_trees.sh
qsub -I -l select=1:ncpus=6:mem=6gb:scratch_local=10gb -l walltime=1:00:00 -- /storage/projects2/InterCOST/trees/qsm_test_trees.sh

qsub -l select=1:ncpus=12:mem=14gb:scratch_local=25gb -l walltime=24:00:00 /storage/projects2/InterCOST/trees/qsm_bc_trees.sh
qsub -l select=1:ncpus=16:mem=32gb:scratch_local=25gb -l walltime=24:00:00 /storage/projects2/InterCOST/trees/qsm_cg_trees.sh

qsub -l select=1:ncpus=12:mem=24gb:scratch_local=25gb -l walltime=2:00:00 /storage/projects2/InterCOST/trees/qsm_bc_trees.sh
qsub -l select=1:ncpus=24:mem=24gb:scratch_local=10gb -l walltime=2:00:00 /storage/projects2/InterCOST/trees/qsm_cg_trees.sh

qsub -I -l select=1:ncpus=4:mem=4gb:scratch_local=5gb -l walltime=00:30:00 -- /storage/projects2/InterCOST/trees/create_qsm.sh /storage/projects2/InterCOST/trees/test_trees/las/00056238b943.las
qsub -- create_qsm.sh /storage/projects2/InterCOST/trees/test_trees/las/00056238b943.las

#PBS -N create_qsm
#PBS -l select=1:ncpus=4:mem=4gb:scratch_local=5gb
#PBS -l walltime=00:30:00 

qsub -I -- /storage/projects2/InterCOST/create_qsm.sh /storage/projects2/InterCOST/trees/test_trees/las/00056238b943.las
qsub -I -- /storage/projects2/InterCOST/create_qsm.sh /storage/projects2/InterCOST/trees/test_trees/las/00056238b943.las

chmod -R g=rwx /storage/projects2/InterCOST
chgrp -R intercost /storage/projects2/InterCOST

# Sestavení MATLAB příkazu
MATLAB_CMD=$(cat <<EOF
try
    cd('/auto/plzen1/projects2/InterCOST/trees');
    addpath(genpath('TreeQSM'));
    lasReader = lasFileReader('$LAS_FILE');
    ptCloud = readPointCloud(lasReader);
    P = ptCloud.Location;
    P = P - mean(P);
    inputs = define_input(P, 1, 1, 1);
    QSMmodel = treeqsm(P, inputs);
    saveFilePath = fullfile('$LAS_DIR', strcat('$LAS_NAME', '_QSM.mat'));
    save(saveFilePath, 'QSMmodel');
    fprintf('Model uložen: %s\n', saveFilePath);
catch ME
    fprintf('Chyba: %s\n', ME.message);
end
exit
EOF
)

# Spuštění MATLABu
matlab -nodisplay -nosplash -r "$MATLAB_CMD"


qsub -I -l select=1:ncpus=1:mem=1gb:scratch_local=1gb -l walltime=00:1:00 -- /storage/projects2/InterCOST/trees/run_qsm.sh /storage/projects2/InterCOST/trees/test_trees/las/00056238b943.las

qsub -I -l select=1:ncpus=1:mem=1gb:scratch_local=1gb -l walltime=00:1:00 -- /storage/projects2/InterCOST/trees/run_qsm.sh

@

sync_with_group bluecat /storage/projects2/InterCOST/singularity_img/pdal.img /storage/brno2/home/krucek/bluecat/singularity_img/pdal.img
sync_with_group bluecat /storage/projects2/InterCOST/singularity_img/lastools.img /storage/brno2/home/krucek/bluecat/singularity_img/lastools.img
sync_with_group bluecat /storage/projects2/InterCOST/singularity_img/cloudcompare.img /storage/brno2/home/krucek/bluecat/singularity_img/cloudcompare.img
sync_with_group bluecat /storage/projects2/InterCOST/singularity_img/raycloudtools.img /storage/brno2/home/krucek/bluecat/singularity_img/raycloudtools.img


qsub -l select=1:ncpus=24:mem=64gb:scratch_local=250 -l walltime=12:00:00 -- /storage/plzen1/home/krucek/scripts/segment.sh Doutnac_north_MLS_2025.laz /storage/plzen1/home/krucek/data/doutnac true 0.02 true
qsub -l select=1:ncpus=24:mem=64gb:scratch_local=250 -l walltime=12:00:00 -- /storage/plzen1/home/krucek/scripts/segment.sh Doutnac_south_MLS_2025.laz /storage/plzen1/home/krucek/data/doutnac true 0.02 true

qsub -l select=1:ncpus=2:mem=4gb:scratch_local=10gb -l walltime=1:00:00 -- /storage/plzen1/home/krucek/scripts/save_first_coord.sh /storage/plzen1/home/krucek/data/doutnac/Doutnac_south_MLS_2025.laz
qsub -l select=1:ncpus=2:mem=4gb:scratch_local=10gb -l walltime=1:00:00 -- /storage/plzen1/home/krucek/scripts/save_first_coord.sh /storage/plzen1/home/krucek/data/doutnac/Doutnac_north_MLS_2025.laz