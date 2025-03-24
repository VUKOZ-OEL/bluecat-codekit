# commands to download data from filesender and copy them to s3 storage
## use of filesender2s3storage.sh
### params $1=url to zip download $2 destination on s3

qsub -l select=1:ncpus=4:mem=16gb:scratch_local=50gb -l walltime=3:00:00 -- /storage/plzen1/home/krucek/scripts/filesender2s3storage.sh "https://filesender.cesnet.cz/download.php?token=a1408ab4-e4bf-4974-bfde-949b5fd7359e&files_ids=672165%2C672164%2C672163%2C672162%2C672161" "s3://wp2/FVA-BW/"