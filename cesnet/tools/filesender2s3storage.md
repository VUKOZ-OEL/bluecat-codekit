qsub -I -l select=1:ncpus=2:mem=4gb:scratch_local=100gb -l walltime=2:00:00 -- /storage/plzen1/home/krucek/scripts/filesender2s3storage.sh "https://filesender.cesnet.cz/download.php?token=2eb3d300-3b86-46a7-a65e-50b0dc1d652d&files_ids=683351%2C683350%2C683349%2C683348%2C683347%2C683346%2C683345" "s3://wp2/FVA-BW/"


## List files to txt

s5cmd --credentials-file "/storage/plzen1/home/krucek/.aws/credentials" --profile s3cmd_access --endpoint-url=https://s3.cl4.du.cesnet.cz ls "s3://wp3/*" > wp3_list.txt
s5cmd --credentials-file "/storage/plzen1/home/krucek/.aws/credentials" --profile s3cmd_access --endpoint-url=https://s3.cl4.du.cesnet.cz ls "s3://wp2/VUK/*" > vuk_list.txt

s5cmd --credentials-file "/storage/plzen1/home/krucek/.aws/credentials" --profile s3cmd_access --endpoint-url=https://s3.cl4.du.cesnet.cz ls "s3://wp2/VUK/" | cat -A





s5cmd --credentials-file "/storage/plzen1/home/krucek/.aws/credentials" --profile s3cmd_access --endpoint-url=https://s3.cl4.du.cesnet.cz ls "s3://wp2"




##	rename file

s5cmd --credentials-file "/storage/plzen1/home/krucek/.aws/credentials" --profile s3cmd_access --endpoint-url=https://s3.cl4.du.cesnet.cz cp "s3://wp2/VUK/VUK__38__Novorecky mocal__NA__ULS.laz" "s3://wp2/VUK/VUK__38__Novorecky_mocal__NA__ULS.laz"


s5cmd --credentials-file "/storage/plzen1/home/krucek/.aws/credentials" --profile s3cmd_access --endpoint-url=https://s3.cl4.du.cesnet.cz ls "s3://wp2"
s5cmd --credentials-file "/storage/plzen1/home/krucek/.aws/credentials" --profile s3cmd_access --endpoint-url=https://s3.cl4.du.cesnet.cz ls "s3://wp2"

ln -s /storage/plzen1/home/krucek/.aws/config ~/.aws/config

cp -r /storage/plzen1/home/krucek/.aws $HOME



cat > ~/.aws/credentials <<EOF
[default]
aws_access_key_id = OTPPGGLB4E4E6UAJAOCX
aws_secret_access_key = jo5jU04eAfkqGwHHvW3Al1dDvTzM9dY2BJr1zlH0

[s3cmd_access]
aws_access_key_id = OTPPGGLB4E4E6UAJAOCX
aws_secret_access_key = jo5jU04eAfkqGwHHvW3Al1dDvTzM9dY2BJr1zlH0
EOF

cat > ~/.aws/config <<EOF
[default]
region = us-west-2
s3 =
    endpoint_url = https://s3.cl4.du.cesnet.cz

[profile s3cmd_access]
region = us-west-2
s3 =
    endpoint_url = https://s3.cl4.du.cesnet.cz
EOF

s3cmd --credentials-file "/storage/plzen1/home/krucek/.aws/credentials" --profile s3cmd_access --endpoint-url=https://s3.cl4.du.cesnet.cz mb s3://forestumai

s5cmd --credentials-file "/storage/plzen1/home/krucek/.aws/credentials" --profile s3cmd_access --endpoint-url=https://s3.cl4.du.cesnet.cz ls "s3://wp2/VUK*"

s5cmd --credentials-file "/storage/plzen1/home/krucek/.aws/credentials" --profile s3cmd_access --endpoint-url=https://s3.cl4.du.cesnet.cz --json stat s3://wp2




aws s3api get-bucket-policy --profile s3wildcard --endpoint-url https://s3.cl2.du.cesnet.cz --bucket wp2
aws s3api get-bucket-policy --bucket wp2 --endpoint-url https://s3.cl4.du.cesnet.cz