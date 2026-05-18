#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="${TMPDIR:-/tmp}/code-snuggie-acceptance-$$"

cleanup() {
  rm -rf "$tmp"
}
trap cleanup EXIT

mkdir -p "$tmp/jobs"

assert_file() {
  if [[ ! -f "$1" ]]; then
    echo "Missing expected file: $1" >&2
    exit 1
  fi
}

assert_contains() {
  local file="$1"
  local text="$2"
  if ! grep -Fq "$text" "$file"; then
    echo "Expected $file to contain: $text" >&2
    exit 1
  fi
}

echo "Checking safe fixture devcontainers..."
node "$root/scripts/check-devcontainer.mjs" "$root/fixtures/acceptance/remotion/.devcontainer/devcontainer.json"
node "$root/scripts/check-devcontainer.mjs" "$root/fixtures/acceptance/excalidraw/.devcontainer/devcontainer.json"

echo "Checking unsafe fixture is rejected..."
if node "$root/scripts/check-devcontainer.mjs" "$root/fixtures/acceptance/unsafe-devcontainer/.devcontainer/devcontainer.json" >"$tmp/unsafe-check.out" 2>&1; then
  cat "$tmp/unsafe-check.out" >&2
  echo "Unsafe fixture unexpectedly passed." >&2
  exit 1
fi

echo "Creating representative jobs..."
CODE_SNUGGIE_JOBS_DIR="$tmp/jobs" bash "$root/scripts/new-job.sh" remotion https://www.npmjs.com/package/remotion >/dev/null
CODE_SNUGGIE_JOBS_DIR="$tmp/jobs" bash "$root/scripts/new-job.sh" excalidraw https://github.com/excalidraw/excalidraw >/dev/null

cp -R "$root/fixtures/acceptance/remotion/." "$tmp/jobs/remotion/workspace/"
cp -R "$root/fixtures/acceptance/excalidraw/." "$tmp/jobs/excalidraw/workspace/"

assert_file "$tmp/jobs/remotion/JOB.md"
assert_file "$tmp/jobs/remotion/SOURCE.json"
assert_file "$tmp/jobs/remotion/VALIDATION.md"
assert_file "$tmp/jobs/remotion/workspace/.devcontainer/devcontainer.json"
assert_contains "$tmp/jobs/remotion/SOURCE.json" '"type": "npm"'
assert_contains "$tmp/jobs/remotion/workspace/package.json" 'create-video@latest'

assert_file "$tmp/jobs/excalidraw/JOB.md"
assert_file "$tmp/jobs/excalidraw/SOURCE.json"
assert_file "$tmp/jobs/excalidraw/VALIDATION.md"
assert_file "$tmp/jobs/excalidraw/workspace/.devcontainer/devcontainer.json"
assert_contains "$tmp/jobs/excalidraw/SOURCE.json" '"type": "github"'
assert_contains "$tmp/jobs/excalidraw/workspace/package.json" '"packageManager": "yarn@1.22.22"'

CODE_SNUGGIE_JOBS_DIR="$tmp/jobs" bash "$root/scripts/validation-summary.sh" remotion >/dev/null
CODE_SNUGGIE_JOBS_DIR="$tmp/jobs" bash "$root/scripts/validation-summary.sh" excalidraw >/dev/null

if CODE_SNUGGIE_JOBS_DIR="$tmp/jobs" bash "$root/scripts/clone-github-source.sh" remotion file:///tmp/example.git >"$tmp/invalid-clone.out" 2>&1; then
  cat "$tmp/invalid-clone.out" >&2
  echo "Invalid clone source unexpectedly passed." >&2
  exit 1
fi

CODE_SNUGGIE_JOBS_DIR="$tmp/jobs" bash "$root/scripts/new-job.sh" secret-fixture https://www.npmjs.com/package/remotion >/dev/null
printf 'OPENAI_API_KEY=sk-placeholder\n' > "$tmp/jobs/secret-fixture/workspace/.env"
if CODE_SNUGGIE_JOBS_DIR="$tmp/jobs" bash "$root/scripts/publish-private-repo.sh" secret-fixture code-snuggie-secret-fixture >"$tmp/secret-publish.out" 2>&1; then
  cat "$tmp/secret-publish.out" >&2
  echo "Secret-containing workspace unexpectedly published." >&2
  exit 1
fi
rm -rf "$tmp/jobs/secret-fixture"

if grep -R -E "(OPENAI_API_KEY|GITHUB_TOKEN|BEGIN [A-Z ]*PRIVATE KEY)" "$tmp/jobs" >/dev/null; then
  echo "Fixture jobs contain committed secret-like material." >&2
  exit 1
fi

echo "Acceptance fixtures passed."
