#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: npm run job:new -- <job-name> <github-url|npm-package-or-url>" >&2
  exit 64
}

slugify() {
  printf '%s' "$1" \
    | tr '[:upper:]' '[:lower:]' \
    | sed -E 's/[^a-z0-9._-]+/-/g; s/^-+//; s/-+$//'
}

if [[ $# -lt 2 ]]; then
  usage
fi

name="$(slugify "$1")"
source_ref="$2"

if [[ -z "$name" ]]; then
  echo "Job name must contain at least one letter or number." >&2
  exit 65
fi

jobs_dir="${CODE_SNUGGIE_JOBS_DIR:-.code-snuggie/jobs}"
job_dir="$jobs_dir/$name"

if [[ -e "$job_dir" ]]; then
  echo "Job already exists: $job_dir" >&2
  exit 73
fi

mkdir -p "$job_dir/workspace" "$job_dir/artifacts"

source_type="unknown"
case "$source_ref" in
  https://github.com/*|git@github.com:*)
    source_type="github"
    ;;
  https://www.npmjs.com/package/*|npm:*)
    source_type="npm"
    ;;
  *)
    if [[ "$source_ref" != *"/"* || "$source_ref" == @*/* ]]; then
      source_type="npm"
    fi
    ;;
esac

created_at="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

cat > "$job_dir/JOB.md" <<EOF
# $name

## Source

- Type: $source_type
- Ref: $source_ref
- Created: $created_at

## Goal

Create a private GitHub repository with a reliable, secure, Codespaces-ready development environment.

## Status

- [ ] Source inspected
- [ ] Devcontainer created or revised
- [ ] Dependencies installed
- [ ] Checks/builds run
- [ ] Dev server smoke checked
- [ ] Security review documented
- [ ] Private repository pushed
EOF

cat > "$job_dir/SOURCE.json" <<EOF
{
  "name": "$name",
  "type": "$source_type",
  "ref": "$source_ref",
  "createdAt": "$created_at"
}
EOF

cat > "$job_dir/LOG.md" <<EOF
# Log

## $created_at

- Created job scaffold.
EOF

cat > "$job_dir/VALIDATION.md" <<EOF
# Validation

## Commands

Record each command, where it ran, and whether it passed.

## Security Review

- Privileged mode:
- Host networking:
- Docker socket:
- Host credential mounts:
- Repository permissions:
- Secrets committed:
- Egress posture:

## Result

Pending.
EOF

echo "$job_dir"
