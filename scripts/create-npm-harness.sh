#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: npm run job:npm-harness -- <job-name> <package-or-npm-url> [create-command...]" >&2
  exit 64
}

if [[ $# -lt 2 ]]; then
  usage
fi

job_name="$1"
package_ref="$2"
shift 2

jobs_dir="${CODE_SNUGGIE_JOBS_DIR:-.code-snuggie/jobs}"
job_dir="$jobs_dir/$job_name"
workspace="$job_dir/workspace"

if [[ ! -d "$job_dir" ]]; then
  echo "Missing job: $job_dir" >&2
  exit 66
fi

mkdir -p "$workspace"

package_name="$package_ref"
case "$package_ref" in
  https://www.npmjs.com/package/*)
    package_name="${package_ref#https://www.npmjs.com/package/}"
    package_name="${package_name%%\?*}"
    ;;
  npm:*)
    package_name="${package_ref#npm:}"
    ;;
esac

if [[ $# -gt 0 ]]; then
  command=("$@")
else
  command=("npm" "create" "$package_name@latest" "--" ".")
fi

if [[ -n "$(find "$workspace" -mindepth 1 -maxdepth 1 -print -quit)" ]]; then
  echo "Workspace is not empty: $workspace" >&2
  exit 73
fi

(
  cd "$workspace"
  "${command[@]}"
)

{
  echo
  echo "## $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  echo
  printf -- "- Created npm harness with: "
  printf '`%q` ' "${command[@]}"
  echo
} >> "$job_dir/LOG.md"

echo "$workspace"
