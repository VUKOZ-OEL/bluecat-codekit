#!/bin/bash
set -euo pipefail

source "$(dirname "$0")/../common.sh"

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <filesender_url> <s3_target>"
  exit 1
fi

FILESENDER_URL="$1"
S3_TARGET="$2"

cesnet::enter_scratch
wget --progress=bar:force -O data.zip "$FILESENDER_URL"
unzip -q data.zip -d data
s5cmd --credentials-file "/storage/plzen1/home/krucek/.aws/credentials" --profile s3cmd_access --endpoint-url=https://s3.cl4.du.cesnet.cz cp "data/*" "$S3_TARGET"
cesnet::clean_scratch
