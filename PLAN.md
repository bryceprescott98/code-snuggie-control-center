# Code Snuggie Agent Workbench

## Summary

Code Snuggie is a UI-free Codespace project for running Codex as an autonomous repo-setup agent. The project provides a ready devcontainer, a precise `code-snuggie` skill, helper scripts, job folders, and acceptance fixtures so Codex can create Codespaces-ready private GitHub repositories from GitHub repo URLs or npm package specs.

## Key Changes

- [x] First add this repo's own `.devcontainer/devcontainer.json` with `OpenAI.chatgpt`, GitHub CLI, Node/npm, Python, Dev Container CLI, Docker access, and workspace-write defaults.
- [x] Add Codex configuration guidance for a low-friction approval posture:
  - Codex works freely inside this repo and ignored `.code-snuggie/jobs/`.
  - Routine commands are allowed: `git clone`, package installs, builds, tests, devcontainer validation, `gh repo create`, commits, and pushes using ambient auth.
  - Codex asks only for boundary crossings: writes outside workspace/job folders, destructive host operations, undeclared secret access, network/egress expansion, or privileged container settings.
- [x] Strengthen the `code-snuggie` skill with workflows for GitHub repos, npm packages, security review, devcontainer revision, validation, publishing, and failure reporting.
- [x] Add helper scripts for job scaffolding, npm harness creation, static devcontainer checks, validation summaries, and cleanup of old job workspaces.
- [x] Add README guidance for humans and keep the canonical agent workflow in the `code-snuggie` skill.
- [x] Add fixture-style acceptance checks for representative generated projects.
- [x] Run full devcontainer build/start validation when Docker is available.

## GitHub Repo Handling

- Codex must inspect existing devcontainer files but must not accept them as-is.
- If a source repo has devcontainer/Docker/Compose config, Codex revises it for:
  - Security: remove or justify privileged mode, host networking, Docker socket mounts, host credential mounts, root interactive users, broad ports, secrets, and unsafe egress.
  - Efficiency: remove stale template code, unnecessary image builds, oversized apt installs, duplicate setup, and slow lifecycle commands.
  - Reliability: align installs with lockfiles, add required system packages, configure ports/services, and ensure first-open setup works.
  - Agent readiness: include `OpenAI.chatgpt`, useful VS Code extensions, GitHub CLI when appropriate, and restricted egress by default.
- If no devcontainer exists, Codex creates the smallest reliable setup based on repo evidence.

## Job Workflow

- [x] Codex creates `.code-snuggie/jobs/<job-name>/` with `JOB.md`, `SOURCE.json`, `LOG.md`, `VALIDATION.md`, `workspace/`, and optional `artifacts/`.
- Codex clones GitHub repos or creates npm package harnesses, then works only inside the job workspace.
- Codex validates locally before publishing.
- After validation passes, Codex creates a new private GitHub repo and pushes the generated project.
- Failed jobs keep logs, exact failing commands, likely fixes, and whether the blocker is config, source project, auth, network, or tooling.
- [x] Jobs should be idempotent where practical: reruns reuse or clearly replace the job workspace without corrupting prior evidence.

## Acceptance Tests

- Workbench:
  - [x] This repo opens in Codespaces with Codex available as `OpenAI.chatgpt`.
  - [x] Required tools exist: `gh`, `git`, `node`, `npm`, `python`, `docker`, and `devcontainer`.
  - [x] Codex can create job folders and validate devcontainers.
  - [x] Codex has helper commands for cloning GitHub repos and publishing generated workspaces.
  - [ ] Codex can live-clone repos, install dependencies, and push generated repos without repeated routine permission prompts.
- Remotion:
  - Given `https://www.npmjs.com/package/remotion`, Codex creates a repo equivalent to `npx create-video@latest`.
  - The repo has devcontainer support, installs dependencies, runs available checks/builds, starts the Remotion dev workflow, and is pushed privately after validation.
- Excalidraw:
  - Given `https://github.com/excalidraw/excalidraw`, Codex creates a copied private repo with revised Codespaces support.
  - The setup respects Excalidraw's current Yarn 1.22.22 workflow.
  - Validation includes install, practical configured checks/builds, and a dev-server smoke check.
- Security:
  - Generated devcontainers default to restricted egress.
  - Unsafe privileges are removed or justified in `VALIDATION.md`.
  - No secrets are committed.

## Implementation Log

- 2026-05-18: Added `package.json` command surface and helper scripts:
  - `scripts/new-job.sh`
  - `scripts/clone-github-source.sh`
  - `scripts/create-npm-harness.sh`
  - `scripts/publish-private-repo.sh`
  - `scripts/check-devcontainer.mjs`
  - `scripts/validation-summary.sh`
  - `scripts/cleanup-jobs.sh`
- 2026-05-18: Added fixture-style acceptance coverage:
  - Remotion-like npm starter fixture.
  - Excalidraw-like Yarn 1.22.22 GitHub repo fixture.
  - Intentionally unsafe devcontainer fixture.
  - `scripts/run-acceptance-fixtures.sh` validates safe fixtures, rejects unsafe fixtures, creates representative jobs, checks summaries, rejects invalid clone sources, and refuses secret-containing publish attempts.
- 2026-05-18: Consolidated scattered guidance:
  - `README.md` is the human entrypoint.
  - `.codex/skills/code-snuggie-skill/SKILL.md` is the canonical Codex workflow and approval posture.
  - `PLAN.md` remains the temporary implementation checklist/log.
  - Removed duplicate `docs/WORKFLOW.md` and `.agents/README.md`.
- 2026-05-18: Validated local command surface:
  - `npm test` passed.
  - `bash -n scripts/new-job.sh scripts/clone-github-source.sh scripts/create-npm-harness.sh scripts/publish-private-repo.sh scripts/validation-summary.sh scripts/cleanup-jobs.sh scripts/run-acceptance-fixtures.sh` passed.
  - `node --check scripts/check-devcontainer.mjs` passed.
  - `/tmp` job smoke test passed for scaffold, npm harness command path, and validation summary.
- 2026-05-18: Validated devcontainer:
  - `docker info` passed with approved Docker access.
  - `devcontainer build --workspace-folder .` passed.
  - `devcontainer up --workspace-folder .` passed and ran `postCreateCommand`.
  - `.devcontainer/devcontainer-lock.json` was generated to pin resolved Dev Container feature versions.
  - Observed tool versions: `devcontainer 0.87.0`, `gh 2.92.0`, `docker 29.4.3-1`, `git 2.49.0`, `node v22.16.0`, `npm 10.9.2`, `python 3.11.2`.
- 2026-05-18: Built and validated the Remotion example in `.code-snuggie/jobs/code-snuggie-remotion/workspace`:
  - Generated with `npx create-video@latest --yes --blank --no-tailwind .`.
  - Added a repo-specific `.devcontainer/devcontainer.json` using the official Node 22 devcontainer image, GitHub CLI feature, `OpenAI.chatgpt`, ESLint, Prettier, non-root `node`, `npm install`, and Remotion Studio port 3000.
  - `npm install`, `npm run lint`, `npm run build`, `npm audit --audit-level=high`, devcontainer build/up, in-container lint/build, and Remotion Studio smoke check passed.
  - Prepared commit `168d123` in `/tmp/code-snuggie-remotion-publish.Cvhu85` using configured Git identity.
  - Push to `Square-Zero-Labs/code-snuggie-remotion` is blocked by GitHub authorization: `403 Write access to repository not granted`.

## Assumptions

- V1 has no web UI.
- Codex is the primary executor and decision-maker.
- Helper scripts reduce repetitive work but do not replace repo-specific judgment.
- Generated repositories are private by default.
- Auth uses ambient `gh`, `GITHUB_TOKEN`, npm config, and Codespaces secrets.
- Remotion details are checked at implementation time; current npm guidance points to `npx create-video@latest`.
