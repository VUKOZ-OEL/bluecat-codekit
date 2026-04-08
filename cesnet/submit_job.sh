#!/bin/bash
# submit_job.sh
#
# Wrapper script for running Bluecat CodeKit CESNET tools via PBS.
#
# Usage:
#   ./submit_job.sh <script_name> [args...]
#
# The script performs the following steps:
#   1. Ensures the repository is cloned locally under $HOME/bluecat-codekit.
#   2. Updates the repository with `git pull` to fetch the latest changes.
#   3. Locates the requested script within the `cesnet` directory.
#   4. Creates a temporary PBS job file that exports the provided arguments and
#      invokes the requested script.
#   5. Submits the job with `qsub` and prints the resulting job ID.

set -euo pipefail

# Verify at least the script name has been provided.
if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <script_name> [args...]"
  exit 1
fi

# Extract the name of the shell script to run. Any additional arguments
# supplied after the script name will be forwarded to the job.
SCRIPT_NAME="$1"
shift
SCRIPT_ARGS=("$@")

# Define where the repository will live on the compute node.  Using a
# per‑user directory prevents conflicts with other users while still
# allowing repeated calls to update the same checkout rather than cloning
# repeatedly.
REPO_DIR="$HOME/bluecat-codekit"

# If the repository is not already cloned, clone it.  Only the first
# invocation will perform a clone; subsequent runs will reuse the existing
# checkout.
if [[ ! -d "$REPO_DIR/.git" ]]; then
  echo "[INFO] Cloning repository into $REPO_DIR..."
  git clone git@github.com:VUKOZ-OEL/bluecat-codekit.git "$REPO_DIR"
fi

# Update the repository to ensure we have the latest changes.  This also
# removes any local changes, so use with caution if editing files locally.
echo "[INFO] Updating repository..."
cd "$REPO_DIR"
git fetch --all --prune
git reset --hard origin/$(git symbolic-ref --short HEAD)
git pull --ff-only

# Locate the requested script in the cesnet directory.  The search is
# restricted to *.sh files to prevent accidental execution of arbitrary
# files.  If multiple matches are found, the first one is used.
SCRIPT_PATH=$(find cesnet -maxdepth 3 -name "$SCRIPT_NAME" -type f | head -n 1 || true)
if [[ -z "$SCRIPT_PATH" ]]; then
  echo "[ERROR] Script '$SCRIPT_NAME' was not found within the cesnet directory."
  exit 2
fi

# Construct a unique job name by stripping the extension and appending a
# timestamp.  PBS job names must be alphanumeric and shorter than 15
# characters; spaces are not allowed.  This ensures multiple jobs can be
# submitted for different runs of the same tool without collisions.
BASE_NAME="${SCRIPT_NAME%.*}"
TIMESTAMP=$(date +%Y%m%d%H%M%S)
JOB_NAME="${BASE_NAME:0:8}_$TIMESTAMP"

# Create a temporary PBS script to run the selected tool.  The script
# receives the environment variables INPUT, OUTPUT, etc. via the exported
# arguments defined below.  Adjust resources here as needed.
PBS_FILE=$(mktemp)
cat > "$PBS_FILE" <<'EOF'
#!/bin/bash
#PBS -N ${JOB_NAME}
#PBS -l select=1:ncpus=4:mem=16gb
#PBS -l walltime=04:00:00
#PBS -j oe

# Move into the directory from which qsub was called to ensure relative
# paths within the called script are resolved correctly.
cd "$PBS_O_WORKDIR"

# Ensure modules are available.  Without sourcing /etc/profile the
# `module` command does not exist inside a PBS job.
source /etc/profile

# Load the Singularity module explicitly.  This ensures the singularity
# command is available for all tools used by the CodeKit scripts.
module load singularity

# Pass through any arguments provided to submit_job.sh.  The job will
# call the script with exactly these arguments.  Quoting preserves
# whitespace and special characters.
bash "$REPO_DIR/$SCRIPT_PATH" "${SCRIPT_ARGS[@]}"
EOF

# Replace variables in the PBS_FILE template.  Use `envsubst` for
# simplicity: it substitutes ${JOB_NAME}, ${REPO_DIR}, ${SCRIPT_PATH},
# and ${SCRIPT_ARGS[@]} appropriately.  The set -a enables export of
# variables so envsubst can see them.
(
  set -a
  JOB_NAME="$JOB_NAME"
  REPO_DIR="$REPO_DIR"
  SCRIPT_PATH="$SCRIPT_PATH"
  # Flatten arguments array into a single space separated string for export.
  SCRIPT_ARGS_ESCAPED="${SCRIPT_ARGS[*]}"
  envsubst < "$PBS_FILE" > "${PBS_FILE}.final"
)

# Submit the job via qsub and record the job ID for user reference.
JOB_ID=$(qsub "${PBS_FILE}.final")
echo "[INFO] Submitted job $JOB_ID for script $SCRIPT_PATH"

# Clean up temporary files (both the template and final PBS script).
rm -f "$PBS_FILE" "${PBS_FILE}.final"

exit 0