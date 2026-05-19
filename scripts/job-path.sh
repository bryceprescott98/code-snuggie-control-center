#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: npm run job:path -- <job-name>" >&2
  exit 64
}

slugify() {
  printf '%s' "$1" \
    | tr '[:upper:]' '[:lower:]' \
    | sed -E 's/[^a-z0-9._-]+/-/g; s/^-+//; s/-+$//'
}

if [[ $# -lt 1 ]]; then
  usage
fi

name="$(slugify "$1")"
jobs_dir="${CODE_SNUGGIE_JOBS_DIR:-.code-snuggie/jobs}"
job_dir="$jobs_dir/$name"
workspace="$job_dir/workspace"

cat <<EOF
job=$name
job_dir=$job_dir
workspace=$workspace
artifacts=$job_dir/artifacts
EOF
