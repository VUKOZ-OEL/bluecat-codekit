#!/bin/bash
# Wrapper for submitting CESNET scripts as PBS jobs.

set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <script_name> [args...]"
  exit 1
fi

SCRIPT_NAME="$1"
shift
SCRIPT_ARGS=("$@")

REPO_DIR="$HOME/bluecat-codekit"
if [[ ! -d "$REPO_DIR/.git" ]]; then
  echo "[INFO] Cloning repository into $REPO_DIR"
  git clone git@github.com:VUKOZ-OEL/bluecat-codekit.git "$REPO_DIR"
fi

cd "$REPO_DIR"
echo "[INFO] Updating repository"
git fetch --all --prune
git reset --hard "origin/$(git symbolic-ref --short HEAD)"
git pull --ff-only

SCRIPT_PATH=$(find cesnet -maxdepth 4 -type f -name "$SCRIPT_NAME" | head -n 1 || true)
if [[ -z "$SCRIPT_PATH" ]]; then
  echo "[ERROR] Script '$SCRIPT_NAME' was not found in ./cesnet"
  exit 2
fi

BASE_NAME="${SCRIPT_NAME%.*}"
TIMESTAMP=$(date +%Y%m%d%H%M%S)
JOB_NAME="${BASE_NAME:0:8}_$TIMESTAMP"

PBS_FILE=$(mktemp)
{
  echo "#!/bin/bash"
  echo "#PBS -N $JOB_NAME"
  echo "#PBS -l select=1:ncpus=4:mem=16gb"
  echo "#PBS -l walltime=04:00:00"
  echo "#PBS -j oe"
  echo
  echo "set -euo pipefail"
  echo "cd \"$REPO_DIR\""
  echo "source /etc/profile || true"
  echo "module load singularity || module add singul/ || true"
  printf 'bash "%s/%s"' "$REPO_DIR" "$SCRIPT_PATH"
  for arg in "${SCRIPT_ARGS[@]}"; do
    printf ' %q' "$arg"
  done
  echo
} > "$PBS_FILE"

JOB_ID=$(qsub "$PBS_FILE")
echo "[INFO] Submitted job $JOB_ID for script $SCRIPT_PATH"
rm -f "$PBS_FILE"
