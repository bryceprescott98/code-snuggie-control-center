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
node "$root/scripts/check-devcontainer.mjs" "$root/tests/fixtures/acceptance/remotion/.devcontainer/devcontainer.json"
node "$root/scripts/check-devcontainer.mjs" "$root/tests/fixtures/acceptance/excalidraw/.devcontainer/devcontainer.json"
node "$root/scripts/check-devcontainer.mjs" --require-restricted-egress "$root/tests/fixtures/acceptance/remotion/.devcontainer/devcontainer.json"

echo "Checking unsafe fixture is rejected..."
if node "$root/scripts/check-devcontainer.mjs" "$root/tests/fixtures/acceptance/unsafe-devcontainer/.devcontainer/devcontainer.json" >"$tmp/unsafe-check.out" 2>&1; then
  cat "$tmp/unsafe-check.out" >&2
  echo "Unsafe fixture unexpectedly passed." >&2
  exit 1
fi

mkdir -p "$tmp/overbroad-repo-access/.devcontainer"
cat > "$tmp/overbroad-repo-access/.devcontainer/devcontainer.json" <<'EOF'
{
  "image": "mcr.microsoft.com/devcontainers/javascript-node:1-20-bookworm",
  "customizations": {
    "vscode": {
      "extensions": ["OpenAI.chatgpt"]
    },
    "codespaces": {
      "repositories": {
        "example/generated-app": {
          "permissions": {
            "contents": "write",
            "pull_requests": "write",
            "workflows": "write"
          }
        }
      }
    }
  }
}
EOF
if node "$root/scripts/check-devcontainer.mjs" "$tmp/overbroad-repo-access/.devcontainer/devcontainer.json" >"$tmp/overbroad-repo-access.out" 2>&1; then
  cat "$tmp/overbroad-repo-access.out" >&2
  echo "Overbroad repository-access fixture unexpectedly passed." >&2
  exit 1
fi
assert_contains "$tmp/overbroad-repo-access.out" "Overbroad Codespaces repository permission"

mkdir -p "$tmp/missing-egress/.devcontainer"
cat > "$tmp/missing-egress/.devcontainer/devcontainer.json" <<'EOF'
{
  "image": "mcr.microsoft.com/devcontainers/javascript-node:1-20-bookworm",
  "customizations": {
    "vscode": {
      "extensions": ["OpenAI.chatgpt"]
    }
  }
}
EOF
if node "$root/scripts/check-devcontainer.mjs" --require-restricted-egress "$tmp/missing-egress/.devcontainer/devcontainer.json" >"$tmp/missing-egress.out" 2>&1; then
  cat "$tmp/missing-egress.out" >&2
  echo "Missing restricted-egress fixture unexpectedly passed." >&2
  exit 1
fi
assert_contains "$tmp/missing-egress.out" "Restricted egress requires dockerComposeFile plus service"

echo "Creating representative jobs..."
CODE_SNUGGIE_JOBS_DIR="$tmp/jobs" bash "$root/scripts/new-job.sh" remotion https://www.npmjs.com/package/remotion >/dev/null
CODE_SNUGGIE_JOBS_DIR="$tmp/jobs" bash "$root/scripts/new-job.sh" excalidraw https://github.com/excalidraw/excalidraw >/dev/null
CODE_SNUGGIE_JOBS_DIR="$tmp/jobs" bash "$root/scripts/job-path.sh" remotion >"$tmp/remotion-path.out"
assert_contains "$tmp/remotion-path.out" "job_dir=$tmp/jobs/remotion"
assert_contains "$tmp/remotion-path.out" "workspace=$tmp/jobs/remotion/workspace"
assert_contains "$tmp/remotion-path.out" "artifacts=$tmp/jobs/remotion/artifacts"

cp -R "$root/tests/fixtures/acceptance/remotion/." "$tmp/jobs/remotion/workspace/"
cp -R "$root/tests/fixtures/acceptance/excalidraw/." "$tmp/jobs/excalidraw/workspace/"

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

echo "Checking publish opens a PR from a shared-history branch..."
CODE_SNUGGIE_JOBS_DIR="$tmp/jobs" bash "$root/scripts/new-job.sh" publish-fixture https://www.npmjs.com/package/remotion >/dev/null
cp -R "$root/tests/fixtures/acceptance/remotion/." "$tmp/jobs/publish-fixture/workspace/"
git init --bare "$tmp/target.git" >/dev/null
mkdir -p "$tmp/bin"
cat > "$tmp/bin/gh" <<EOF
#!/usr/bin/env bash
set -euo pipefail
case "\$1 \$2" in
  "repo view")
    if [[ "\$*" == *"--json url"* ]]; then
      printf '%s\n' "$tmp/target.git"
    elif [[ "\$*" == *"--json defaultBranchRef"* ]]; then
      printf '\n'
    fi
    ;;
  "repo create")
    exit 0
    ;;
  "pr list")
    printf '\n'
    ;;
  "pr create")
    printf 'https://example.test/pull/1\n'
    ;;
  *)
    echo "Unexpected gh call: \$*" >&2
    exit 1
    ;;
esac
EOF
chmod +x "$tmp/bin/gh"
env \
  PATH="$tmp/bin:$PATH" \
  CODE_SNUGGIE_JOBS_DIR="$tmp/jobs" \
  GIT_AUTHOR_NAME="Fixture User" \
  GIT_AUTHOR_EMAIL="fixture@example.test" \
  GIT_COMMITTER_NAME="Fixture User" \
  GIT_COMMITTER_EMAIL="fixture@example.test" \
  bash "$root/scripts/publish-private-repo.sh" publish-fixture fixture/repo "Fixture PR" >"$tmp/publish.out"
assert_contains "$tmp/publish.out" "https://example.test/pull/1"
assert_contains "$tmp/jobs/publish-fixture/LOG.md" "Opened pull request: https://example.test/pull/1"
if ! git --git-dir="$tmp/target.git" rev-parse --verify main >/dev/null; then
  echo "Publish fixture did not seed main." >&2
  exit 1
fi
if ! git --git-dir="$tmp/target.git" merge-base --is-ancestor main code-snuggie/publish-fixture; then
  echo "Publish branch does not share history with main." >&2
  exit 1
fi

if grep -R -E "(OPENAI_API_KEY|GITHUB_TOKEN|BEGIN [A-Z ]*PRIVATE KEY)" "$tmp/jobs" >/dev/null; then
  echo "Fixture jobs contain committed secret-like material." >&2
  exit 1
fi

echo "Acceptance fixtures passed."
