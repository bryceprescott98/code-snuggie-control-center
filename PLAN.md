# Code Snuggie Agent Workbench

## Summary

Code Snuggie is a UI-free Codespace project for running Codex as an autonomous repo-setup agent. The project provides a ready devcontainer, a precise `code-snuggie` skill, helper scripts, job folders, and acceptance fixtures so Codex can create Codespaces-ready private GitHub repositories from GitHub repo URLs or npm package specs.

## Key Changes

- First add this repo's own `.devcontainer/devcontainer.json` with `OpenAI.chatgpt`, GitHub CLI, Node/npm, Python, Dev Container CLI, Docker access, and workspace-write defaults.
- Add Codex configuration guidance for a low-friction approval posture:
  - Codex works freely inside this repo and ignored `.code-snuggie/jobs/`.
  - Routine commands are allowed: `git clone`, package installs, builds, tests, devcontainer validation, `gh repo create`, commits, and pushes using ambient auth.
  - Codex asks only for boundary crossings: writes outside workspace/job folders, destructive host operations, undeclared secret access, network/egress expansion, or privileged container settings.
- Strengthen the `code-snuggie` skill with workflows for GitHub repos, npm packages, security review, devcontainer revision, validation, publishing, and failure reporting.
- Add helper scripts for job scaffolding, npm harness creation, static devcontainer checks, validation summaries, and cleanup of old job workspaces.

## GitHub Repo Handling

- Codex must inspect existing devcontainer files but must not accept them as-is.
- If a source repo has devcontainer/Docker/Compose config, Codex revises it for:
  - Security: remove or justify privileged mode, host networking, Docker socket mounts, host credential mounts, root interactive users, broad ports, secrets, and unsafe egress.
  - Efficiency: remove stale template code, unnecessary image builds, oversized apt installs, duplicate setup, and slow lifecycle commands.
  - Reliability: align installs with lockfiles, add required system packages, configure ports/services, and ensure first-open setup works.
  - Agent readiness: include `OpenAI.chatgpt`, useful VS Code extensions, GitHub CLI when appropriate, and restricted egress by default.
- If no devcontainer exists, Codex creates the smallest reliable setup based on repo evidence.

## Job Workflow

- Codex creates `.code-snuggie/jobs/<job-name>/` with `JOB.md`, `SOURCE.json`, `LOG.md`, `VALIDATION.md`, `workspace/`, and optional `artifacts/`.
- Codex clones GitHub repos or creates npm package harnesses, then works only inside the job workspace.
- Codex validates locally before publishing.
- After validation passes, Codex creates a new private GitHub repo and pushes the generated project.
- Failed jobs keep logs, exact failing commands, likely fixes, and whether the blocker is config, source project, auth, network, or tooling.
- Jobs should be idempotent where practical: reruns reuse or clearly replace the job workspace without corrupting prior evidence.

## Acceptance Tests

- Workbench:
  - This repo opens in Codespaces with Codex available as `OpenAI.chatgpt`.
  - Required tools exist: `gh`, `git`, `node`, `npm`, `python`, `docker`, and `devcontainer`.
  - Codex can create job folders, clone repos, install dependencies, validate devcontainers, and push generated repos without repeated routine permission prompts.
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

## Assumptions

- V1 has no web UI.
- Codex is the primary executor and decision-maker.
- Helper scripts reduce repetitive work but do not replace repo-specific judgment.
- Generated repositories are private by default.
- Auth uses ambient `gh`, `GITHUB_TOKEN`, npm config, and Codespaces secrets.
- Remotion details are checked at implementation time; current npm guidance points to `npx create-video@latest`.
