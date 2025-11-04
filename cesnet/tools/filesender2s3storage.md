qsub -I -l select=1:ncpus=2:mem=4gb:scratch_local=100gb -l walltime=2:00:00 -- /storage/plzen1/home/krucek/scripts/filesender2s3storage.sh "https://filesender.cesnet.cz/download.php?token=2eb3d300-3b86-46a7-a65e-50b0dc1d652d&files_ids=683351%2C683350%2C683349%2C683348%2C683347%2C683346%2C683345" "s3://wp2/FVA-BW/"


## List files to txt

s5cmd --credentials-file "/storage/plzen1/home/krucek/.aws/credentials" --profile s3cmd_access --endpoint-url=https://s3.cl4.du.cesnet.cz ls "s3://wp3/*" > wp3_list.txt
s5cmd --credentials-file "/storage/plzen1/home/krucek/.aws/credentials" --profile s3cmd_access --endpoint-url=https://s3.cl4.du.cesnet.cz ls "s3://wp2/VUK/*" > vuk_list.txt

s5cmd --credentials-file "/storage/plzen1/home/krucek/.aws/credentials" --profile s3cmd_access --endpoint-url=https://s3.cl4.du.cesnet.cz ls "s3://wp2/VUK/" | cat -A



##	rename file

s5cmd --credentials-file "/storage/plzen1/home/krucek/.aws/credentials" --profile s3cmd_access --endpoint-url=https://s3.cl4.du.cesnet.cz cp "s3://wp2/VUK/VUK__38__Novorecky mocal__NA__ULS.laz" "s3://wp2/VUK/VUK__38__Novorecky_mocal__NA__ULS.laz"