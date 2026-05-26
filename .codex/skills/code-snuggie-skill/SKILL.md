---
name: code-snuggie
description: Create reliable GitHub Codespaces and Dev Containers configuration for a repository. Use when Codex needs to inspect a repo and add or repair `.devcontainer/devcontainer.json`, `.devcontainer/Dockerfile`, or related Docker Compose/devcontainer files so users can open a working codespace and immediately install, run, test, and develop the project. Covers Node.js/TypeScript and Python projects, validation gates, ports, secrets, VS Code customizations, and first-open reliability.
---

# Code Snuggie

## Goal

Create a dev container setup that works before handoff. Prefer a small, boring configuration that matches the repo's existing tooling over a clever generic template.

## Workflow

The npm commands below are for Codex to run from the Code Snuggie Control Center. Do not ask the human to run them during a normal Code Snuggie job; the human should only provide the source repo or npm package and the destination GitHub repository.

1. Create or use a job workspace when operating from the Code Snuggie Control Center:
   - Start with `npm run job:new -- <job-name> <github-url|npm-package-or-url>`.
   - Use `npm run job:path -- <job-name>` whenever there is any doubt about where a job lives.
   - For GitHub sources, clone with `npm run job:clone -- <job-name> <github-url> [ref]`.
   - For npm starter sources, generate with `npm run job:npm-harness -- <job-name> <package-or-url> [create-command...]`.
   - The canonical job root is `.code-snuggie/jobs/<job-name>/`.
   - The cloned or generated project is always in `.code-snuggie/jobs/<job-name>/workspace/`. Do not look for generated project files at the repository root or directly under `.code-snuggie/jobs/`.
   - `npm run test:live` also defaults to `.code-snuggie/jobs/`; only use another location when `CODE_SNUGGIE_LIVE_JOBS_DIR` or `CODE_SNUGGIE_JOBS_DIR` is explicitly set.
   - Keep `JOB.md`, `LOG.md`, and `VALIDATION.md` current as work proceeds.
2. Inspect the destination repository before publishing assumptions leak into the job:
   - Before opening or updating a PR, inspect the target repository's default branch and existing files with `gh repo view`, `gh api repos/<owner>/<repo>/contents`, or a clean clone.
   - Treat target `main` as real project context, even when generating from an npm starter. Preserve or intentionally replace existing files only after looking at them.
   - Do not publish directly from a generated starter's own `.git` history. Many starter CLIs initialize git; use a clean clone of the destination repo or `npm run job:publish`, which publishes from `.code-snuggie/jobs/<job-name>/publish/` so the PR branch shares history with the target default branch.
3. Inspect the source repo before choosing a container shape:
   - Manifests and lockfiles: `package.json`, `package-lock.json`, `pnpm-lock.yaml`, `yarn.lock`, `pyproject.toml`, `requirements*.txt`, `uv.lock`, `poetry.lock`, `Pipfile.lock`, `environment.yml`.
   - Version hints: `.nvmrc`, `.node-version`, `engines.node`, `.python-version`, `runtime.txt`, `requires-python`.
   - Entrypoints and checks: README setup steps, scripts, Makefile targets, CI workflows, Dockerfiles, Compose files, test config, lint/typecheck config.
   - Runtime needs: ports, databases, Redis, queues, browsers, native packages, OS libraries, private registries, required environment variables. For web apps, inspect env files and framework config for the actual dev port; do not rely on framework defaults alone.
4. Select the simplest reproducible shape:
   - Use `.devcontainer/devcontainer.json` as the default location.
   - Use an official `mcr.microsoft.com/devcontainers/...` image when it already covers the runtime.
   - Ensure every generated development container has `ripgrep` and `jq` installed so Codex can navigate source quickly and inspect structured command output inside the codespace. Add a small `.devcontainer/Dockerfile` or equivalent image-build step when the base image does not explicitly provide them.
   - Check the official Dev Container Features catalog when adding portable tools such as GitHub CLI, Node, Python, Docker-in-Docker, or common CLIs: https://containers.dev/features
   - Before adding or keeping a Dev Container Feature version, confirm the latest available major version from the official catalog or the feature's source `devcontainer-feature.json`, and use that latest major unless the repo has a specific compatibility reason to stay older. Record any intentional older pin in `VALIDATION.md`.
   - Check the official Dev Container Templates catalog when a repo closely matches a standard stack, but adapt the result to the repo instead of copying a generic template wholesale: https://containers.dev/templates
   - Add `.devcontainer/Dockerfile` only for apt packages, browser/system libraries, native build dependencies, or tools that should be cached in the image.
   - Use Docker Compose when the repo already depends on app-adjacent services or has a working compose setup. Keep the development service alive with a sleep loop if its normal command exits.
   - For generated AI-agent-facing Codespaces, default to restricted egress. Read `references/networking.md` and adapt `templates/egress-proxy/`, which uses Squid as the bundled default proxy implementation. Use unrestricted egress only when validation proves the allowlist is not viable yet, and record the reason in `VALIDATION.md`.
5. Preserve repo conventions:
   - Use the package manager and install mode implied by the lockfile.
   - Configure `postCreateCommand` or an equivalent lifecycle command so dependencies are installed before the user starts development.
   - Keep the interactive development user non-root, normally the devcontainer image's `vscode` user. Do not set `remoteUser`, Compose `user`, or app/lifecycle commands to `root` unless the repo has a documented requirement and the risk is explained.
   - Do not add passwordless sudo for generated users by default, including sudoers entries such as `vscode ALL=(root) NOPASSWD:ALL`. If a repo has a documented development need for sudo inside the running container, explain the risk in `VALIDATION.md` and keep the permission as narrow as practical.
   - Use the runtime version implied by repo files; if no version is discoverable, choose the current stable official devcontainer image and note the assumption.
   - Do not replace existing Docker/Compose semantics unless they are clearly unsuitable for development.
   - Keep lifecycle commands non-interactive and finite. If a package-manager shim or tool activation needs root-owned global paths, do that in the image build instead of in `postCreateCommand`.
   - For browser-starting dev servers, disable automatic browser launch with a non-secret environment default when the repo supports it, such as `BROWSER=none`, rather than installing desktop opener tools just to satisfy `open`.
6. Add VS Code customizations:
   - Always include `OpenAI.chatgpt` in `customizations.vscode.extensions`.
   - Add stack-specific extensions only when they clearly improve first-open use, such as `dbaeumer.vscode-eslint`, `esbenp.prettier-vscode`, `ms-python.python`, `ms-python.vscode-pylance`, or `ms-python.black-formatter`.
7. Limit Codespaces repository access:
   - Treat `customizations.codespaces.repositories` as a sensitive privilege boundary because repo startup code, lifecycle commands, package scripts, and extensions can run with the Codespaces token.
   - Grant access only to exact destination repositories needed for the job. Do not use broad owner/org patterns or extra repositories for convenience.
   - Default destination-repo permissions are only `contents: write` and `pull_requests: write`; omit everything else unless the user explicitly approves and the reason is recorded in `VALIDATION.md`.
   - Do not grant `actions`, `workflows`, `administration`, `packages`, `secrets`, or other write scopes by default. If workflow-file changes are required, prefer documenting the limitation or asking for a narrowly scoped follow-up token/app instead of broadening the Codespaces token.
   - Confirm generated devcontainers do not request expanded repository permissions unless the target project itself has a clear Codespaces need.
8. Handle secrets safely:
   - Never write secret values into committed files.
   - If a variable is required, document it with `secrets` in `devcontainer.json` or with a committed `.env.example` only when the repo already uses that convention.
   - Use `remoteEnv` or `containerEnv` only for non-secret defaults.
9. Validate before handoff:
   - Read `references/validation.md`.
   - Run `npm run check:devcontainer -- <workspace>/.devcontainer/devcontainer.json` from the Code Snuggie Control Center when available.
   - Run `npm run check:devcontainer -- --require-restricted-egress <workspace>/.devcontainer/devcontainer.json` before publishing generated AI-agent-facing Codespaces, unless unrestricted egress was explicitly approved and documented.
   - Use `npm test` for deterministic Control Center fixtures.
   - Use `npm run test:live -- [remotion|excalidraw|all]` only when real network/package/GitHub validation is intended.
   - Build and start the dev container when Docker/devcontainer tooling is available.
   - Run the repo's install, checks, and start smoke test inside the container.
   - Confirm `rg --version` and `jq --version` work inside the development container.
   - For web apps, run the exact documented start command, not a one-off command with extra flags. Confirm the process binds to `0.0.0.0` when needed, record the actual port printed by the server, and make sure `forwardPorts`/`portsAttributes` match that actual port or documented fallback ports.
   - Avoid leaving validation dev servers running. Stop the smoke-test process and confirm no stray listener is occupying the tested port before judging Codespaces forwarding behavior.
   - Prefer `onAutoForward: "notify"` unless the user asks for automatic browser launch; it is less surprising for VS Code Desktop users and apps with fallback ports.
   - For restricted egress, smoke-test the proxy before blaming npm or package managers: start the proxy, confirm it stays running, and curl a required host such as `https://registry.npmjs.org/npm` from the dev service through `HTTP_PROXY`.
   - If you change the image, lifecycle command, ports, or environment after a failed run, remove or recreate the existing devcontainer and rerun `devcontainer up`; cached containers can hide first-open failures.
   - Update `VALIDATION.md` with every important command, its working directory, result, first failing command if any, and the security review of privileges, networking, repository permissions, mounts, secrets, and egress.
   - Do not claim the setup is ready if the container builds but project dependencies, tests, or documented start commands fail. Report the exact blocker and remaining command.
10. Publish only after validation passes:
   - Confirm no secrets are present.
   - Treat literal CI placeholders such as `${{ secrets.GITHUB_TOKEN }}` as secret references, not leaked values. Still reject real token-looking values and private keys.
   - Confirm generated `.devcontainer/` passes static checks.
   - Push only the generated project workspace, not job metadata.
   - Do not run `git config` or override the commit author. Use the current git identity or standard `GIT_AUTHOR_*` / `GIT_COMMITTER_*` environment variables.
   - Publish by pull request. If the target repository is empty, seed its base branch with an empty commit before committing the generated workspace so the PR branch shares history with the base branch and no rebase is needed.
   - Always inspect the destination default branch before the final publish step. If it already has files, publish from a branch based on that default branch and note any overwritten or removed files in the PR body.
   - Exclude generated `.git/`, dependency folders, build outputs, and local `.env*` files when copying a generated starter into the publish branch. Keep `.env.example` when it is intentional documentation.
   - If the available GitHub token cannot push `.github/workflows/*`, either omit workflow files from the generated PR branch and document that limitation, or stop and ask for a token/app with workflows permission when preserving workflows is required.
   - After a PR exists, prefer normal follow-up commits for fixes so updates are visible in the PR history. Use force-push only when intentionally replacing generated history, and say so explicitly.
   - In the Code Snuggie Control Center, use `npm run job:publish -- <job-name> <repo-name-or-owner/repo> [description]` when ambient `gh` auth is available.
11. Review job learnings after the PR is open:
   - Re-read `LOG.md`, `VALIDATION.md`, failed command output, and any notes from creating or validating the new codespace.
   - Identify failures, flakes, manual workarounds, missing packages, wrong defaults, egress gaps, permission issues, port mistakes, lifecycle friction, or publish limitations that could recur in future jobs.
   - Decide whether each learning belongs in the `code-snuggie` skill, a reference file, a template, `scripts/check-devcontainer.mjs`, acceptance fixtures, or only the job's `VALIDATION.md`.
   - Update the reusable skill/templates/validations when the learning is general, low-risk, and supported by evidence from the job. Keep repo-specific quirks documented only in the job files or PR body.
   - If no reusable update is warranted, explicitly note that in the final response.

## Approval Posture

Routine Control Center actions are expected inside this repository and `.code-snuggie/jobs/`: creating/updating job folders, cloning GitHub repositories into job workspaces, installing dependencies, running builds/tests/lints/dev-server smoke checks, running Dev Container validation, and creating private GitHub repositories or pull requests with ambient `gh` auth.

Ask before boundary crossings: writing outside this workspace or job folders, destructive host operations, reading undeclared secrets, expanding network or egress assumptions, or adding privileged containers, host networking, host Docker socket mounts, or broad host credential mounts.

## Reference Selection

- Read `references/node-typescript.md` for JavaScript, TypeScript, Node, frontend, or full-stack Node repos.
- Read `references/python.md` for Python apps, packages, notebooks, APIs, or data projects.
- Read `references/networking.md` when the setup needs Codespaces port behavior, Docker Compose service networking, or AI-agent-safe outbound network controls.
- Read `references/validation.md` for every task before final handoff.
- Use https://containers.dev/features to find current feature IDs and versions when a feature is better than a custom Dockerfile install. Prefer the latest available feature major version unless there is a specific compatibility reason to pin older, and document that reason in `VALIDATION.md`.
- Use https://containers.dev/templates to find official/community templates for comparison, then keep only the parts that fit the target repo.

## Output Expectations

Create or update the minimum necessary files, usually:

- `.devcontainer/devcontainer.json`
- `.devcontainer/Dockerfile` only when needed
- `.devcontainer/docker-compose.yml` or Compose overrides only when needed
- `.devcontainer/squid.conf` only when adapting the bundled Squid egress-proxy template
- `.env.example` only when the repo convention supports it and no secrets are included

In the final response, list the files changed, validation commands run, and any remaining limitation. If validation could not run because Docker or the Dev Container CLI is unavailable, say that plainly and include the exact commands the user should run.
