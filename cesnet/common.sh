#!/bin/bash

# Shared helpers for CESNET scripts invoked directly or via submit_job.sh.

cesnet::repo_root() {
  local script_dir
  script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
  cd "$script_dir/.." >/dev/null 2>&1 && pwd
}

cesnet::log() {
  local level="$1"; shift
  local message="$*"
  local timestamp
  timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  if [[ -n "${LOG_FILE:-}" ]]; then
    echo "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
  else
    echo "[$timestamp] [$level] $message"
  fi
}

cesnet::require_args() {
  local expected="$1"
  local usage="$2"
  if [[ "$#" -lt 2 ]]; then
    :
  fi
  if [[ ${ARGC:-$#} -lt "$expected" ]]; then
    echo "Usage: $usage" >&2
    exit 1
  fi
}

cesnet::require_env() {
  local var
  for var in "$@"; do
    if [[ -z "${!var:-}" ]]; then
      echo "Missing required environment variable: $var" >&2
      exit 1
    fi
  done
}

cesnet::require_file() {
  local file="$1"
  if [[ ! -f "$file" ]]; then
    cesnet::log ERROR "File does not exist: $file"
    exit 1
  fi
}

cesnet::enter_scratch() {
  cesnet::require_env SCRATCHDIR
  mkdir -p "$SCRATCHDIR"
  cd "$SCRATCHDIR"
}

cesnet::load_modules() {
  source /etc/profile >/dev/null 2>&1 || true
  if command -v module >/dev/null 2>&1; then
    module add singul/ >/dev/null 2>&1 || module load singularity >/dev/null 2>&1 || true
  fi
}

cesnet::copy_first_existing() {
  local target="$1"
  shift
  local candidate
  for candidate in "$@"; do
    if [[ -f "$candidate" ]]; then
      cp "$candidate" "$target"
      return 0
    fi
  done
  return 1
}

cesnet::clean_scratch() {
  if command -v clean_scratch >/dev/null 2>&1; then
    clean_scratch
  fi
}
