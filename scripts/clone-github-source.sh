#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: npm run job:clone -- <job-name> <github-url> [ref]" >&2
  exit 64
}

if [[ $# -lt 2 ]]; then
  usage
fi

job_name="$1"
repo_url="$2"
ref="${3:-}"
jobs_dir="${CODE_SNUGGIE_JOBS_DIR:-.code-snuggie/jobs}"
job_dir="$jobs_dir/$job_name"
workspace="$job_dir/workspace"

if [[ ! -d "$job_dir" ]]; then
  echo "Missing job: $job_dir" >&2
  exit 66
fi

if [[ "$repo_url" != https://github.com/* && "$repo_url" != git@github.com:* ]]; then
  echo "Expected a GitHub repository URL." >&2
  exit 65
fi

mkdir -p "$workspace"

if [[ -n "$(find "$workspace" -mindepth 1 -maxdepth 1 -print -quit)" ]]; then
  echo "Workspace is not empty: $workspace" >&2
  exit 73
fi

if [[ -n "$ref" ]]; then
  git clone --depth 1 --branch "$ref" "$repo_url" "$workspace"
else
  git clone --depth 1 "$repo_url" "$workspace"
fi

{
  echo
  echo "## $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  echo
  if [[ -n "$ref" ]]; then
    echo "- Cloned $repo_url at ref \`$ref\` into workspace."
  else
    echo "- Cloned $repo_url into workspace."
  fi
} >> "$job_dir/LOG.md"

echo "$workspace"
