# Code Snuggie Agent Workbench

Code Snuggie is a UI-free Codespace workbench for running Codex as an autonomous repo-setup agent. It gives Codex a ready devcontainer, a local `code-snuggie` skill, repeatable job folders, and small helper scripts for turning GitHub repositories or npm package starters into private, Codespaces-ready repositories.

## Quick Start

Open this repository in Codespaces or a local Dev Container, then run:

```bash
npm test
```

Create a job for a GitHub repository:

```bash
npm run job:new -- excalidraw https://github.com/excalidraw/excalidraw
```

Create a job for an npm starter:

```bash
npm run job:new -- remotion https://www.npmjs.com/package/remotion
npm run job:npm-harness -- remotion remotion npx create-video@latest .
```

Each job lives under `.code-snuggie/jobs/<job-name>/` with:

- `JOB.md` for scope and status
- `SOURCE.json` for machine-readable source metadata
- `LOG.md` for command history and decisions
- `VALIDATION.md` for checks, smoke tests, and security review
- `workspace/` for the cloned or generated project
- `artifacts/` for logs, screenshots, patches, or other evidence

## Commands

```bash
npm run job:new -- <job-name> <github-url|npm-package-or-url>
npm run job:clone -- <job-name> <github-url> [ref]
npm run job:npm-harness -- <job-name> <package-or-npm-url> [create-command...]
npm run job:publish -- <job-name> <repo-name-or-owner/repo> [description]
npm run check:devcontainer -- <path-to-devcontainer.json>
npm run validate:summary -- <job-name>
npm run job:cleanup -- <days-old> [--dry-run]
npm run test:live -- [remotion|excalidraw|all]
```

## Canonical Workflow

The Codex workflow lives in [.codex/skills/code-snuggie-skill/SKILL.md](.codex/skills/code-snuggie-skill/SKILL.md). `PLAN.md` is only the temporary implementation checklist/log for this repo.

`npm test` runs deterministic local fixtures. `npm run test:live` performs real network work and is intentionally opt-in.
