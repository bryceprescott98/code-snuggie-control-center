#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: npm run job:cleanup -- <days-old> [--dry-run]" >&2
  exit 64
}

if [[ $# -lt 1 ]]; then
  usage
fi

days="$1"
dry_run="${2:-}"
jobs_dir="${CODE_SNUGGIE_JOBS_DIR:-.code-snuggie/jobs}"

if ! [[ "$days" =~ ^[0-9]+$ ]]; then
  echo "days-old must be a non-negative integer." >&2
  exit 65
fi

if [[ ! -d "$jobs_dir" ]]; then
  exit 0
fi

find "$jobs_dir" -mindepth 1 -maxdepth 1 -type d -mtime +"$days" -print | while read -r job; do
  if [[ "$dry_run" == "--dry-run" ]]; then
    echo "$job"
  else
    rm -rf "$job"
  fi
done
