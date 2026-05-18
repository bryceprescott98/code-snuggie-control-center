#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: npm run validate:summary -- <job-name>" >&2
  exit 64
}

if [[ $# -lt 1 ]]; then
  usage
fi

jobs_dir="${CODE_SNUGGIE_JOBS_DIR:-.code-snuggie/jobs}"
job_dir="$jobs_dir/$1"

if [[ ! -d "$job_dir" ]]; then
  echo "Missing job: $job_dir" >&2
  exit 66
fi

echo "# $1"
echo
sed -n '1,120p' "$job_dir/JOB.md"
echo
sed -n '1,180p' "$job_dir/VALIDATION.md"
