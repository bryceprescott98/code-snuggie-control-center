#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage: npm run test:live -- [remotion|excalidraw|all]

Environment:
  CODE_SNUGGIE_LIVE_JOBS_DIR    Job output directory. Defaults to .code-snuggie/jobs.
  CODE_SNUGGIE_LIVE_PUBLISH     Set to an owner/repo or repo name to publish the Remotion job.
  CODE_SNUGGIE_LIVE_EXCALIDRAW_INSTALL=1
                                Also run Excalidraw dependency install after clone.

This command performs real network work and may be slow. It does not run in npm test.
EOF
  exit 64
}

mode="${1:-all}"
case "$mode" in
  remotion|excalidraw|all) ;;
  *) usage ;;
esac

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
jobs_dir="${CODE_SNUGGIE_LIVE_JOBS_DIR:-.code-snuggie/jobs}"
mkdir -p "$jobs_dir"

timestamp() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

job_exists() {
  [[ -d "$jobs_dir/$1" ]]
}

append_validation_command() {
  local job_name="$1"
  local cwd="$2"
  local command="$3"
  local result="$4"

  {
    echo
    echo "### $(timestamp)"
    echo
    echo "- Directory: \`$cwd\`"
    echo "- Command: \`$command\`"
    echo "- Result: $result"
  } >> "$jobs_dir/$job_name/VALIDATION.md"
}

run_for_job() {
  local job_name="$1"
  local cwd="$2"
  shift 2

  local command_text
  printf -v command_text '%q ' "$@"

  if (cd "$cwd" && "$@"); then
    append_validation_command "$job_name" "$cwd" "$command_text" "passed"
  else
    append_validation_command "$job_name" "$cwd" "$command_text" "failed"
    return 1
  fi
}

ensure_remotion_job() {
  local job_name="remotion-live"
  local workspace="$jobs_dir/$job_name/workspace"

  if ! job_exists "$job_name"; then
    CODE_SNUGGIE_JOBS_DIR="$jobs_dir" bash "$root/scripts/new-job.sh" "$job_name" https://www.npmjs.com/package/remotion >/dev/null
  fi

  if [[ -z "$(find "$workspace" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null || true)" ]]; then
    CODE_SNUGGIE_JOBS_DIR="$jobs_dir" bash "$root/scripts/create-npm-harness.sh" \
      "$job_name" remotion npx create-video@latest --yes --blank --no-tailwind . >/dev/null
  fi

  run_for_job "$job_name" "$root" npm run check:devcontainer -- "$workspace/.devcontainer/devcontainer.json"

  if [[ -f "$workspace/package.json" ]]; then
    run_for_job "$job_name" "$workspace" npm install
    if npm --prefix "$workspace" run | grep -q " typecheck"; then
      run_for_job "$job_name" "$workspace" npm run typecheck
    fi
    if npm --prefix "$workspace" run | grep -q " build"; then
      run_for_job "$job_name" "$workspace" npm run build
    fi
  fi

  if [[ -n "${CODE_SNUGGIE_LIVE_PUBLISH:-}" ]]; then
    CODE_SNUGGIE_JOBS_DIR="$jobs_dir" bash "$root/scripts/publish-private-repo.sh" "$job_name" "$CODE_SNUGGIE_LIVE_PUBLISH"
  fi
}

ensure_excalidraw_job() {
  local job_name="excalidraw-live"
  local workspace="$jobs_dir/$job_name/workspace"

  if ! job_exists "$job_name"; then
    CODE_SNUGGIE_JOBS_DIR="$jobs_dir" bash "$root/scripts/new-job.sh" "$job_name" https://github.com/excalidraw/excalidraw >/dev/null
  fi

  if [[ -z "$(find "$workspace" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null || true)" ]]; then
    CODE_SNUGGIE_JOBS_DIR="$jobs_dir" bash "$root/scripts/clone-github-source.sh" "$job_name" https://github.com/excalidraw/excalidraw >/dev/null
  fi

  if [[ -f "$workspace/package.json" ]]; then
    if grep -Fq '"packageManager": "yarn@1.22.22"' "$workspace/package.json"; then
      append_validation_command "$job_name" "$workspace" "grep packageManager yarn@1.22.22 package.json" "passed"
    else
      append_validation_command "$job_name" "$workspace" "grep packageManager yarn@1.22.22 package.json" "failed"
      echo "Excalidraw package manager did not match expected Yarn 1.22.22." >&2
      exit 1
    fi
  fi

  if [[ -f "$workspace/.devcontainer/devcontainer.json" ]]; then
    run_for_job "$job_name" "$root" npm run check:devcontainer -- "$workspace/.devcontainer/devcontainer.json"
  fi

  if [[ "${CODE_SNUGGIE_LIVE_EXCALIDRAW_INSTALL:-}" == "1" ]]; then
    run_for_job "$job_name" "$workspace" corepack enable
    run_for_job "$job_name" "$workspace" corepack prepare yarn@1.22.22 --activate
    run_for_job "$job_name" "$workspace" yarn install --frozen-lockfile
  fi
}

case "$mode" in
  remotion)
    ensure_remotion_job
    ;;
  excalidraw)
    ensure_excalidraw_job
    ;;
  all)
    ensure_remotion_job
    ensure_excalidraw_job
    ;;
esac

echo "Live acceptance completed in $jobs_dir."
