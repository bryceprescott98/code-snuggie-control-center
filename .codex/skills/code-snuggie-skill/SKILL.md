---
name: code-snuggie
description: Create reliable GitHub Codespaces and Dev Containers configuration for a repository. Use when Codex needs to inspect a repo and add or repair `.devcontainer/devcontainer.json`, `.devcontainer/Dockerfile`, or related Docker Compose/devcontainer files so users can open a working codespace and immediately install, run, test, and develop the project. Covers Node.js/TypeScript and Python projects, validation gates, ports, secrets, VS Code customizations, and first-open reliability.
---

# Code Snuggie

## Goal

Create a dev container setup that works before handoff. Prefer a small, boring configuration that matches the repo's existing tooling over a clever generic template.

## Workflow

1. Inspect the repo before choosing a container shape:
   - Manifests and lockfiles: `package.json`, `package-lock.json`, `pnpm-lock.yaml`, `yarn.lock`, `pyproject.toml`, `requirements*.txt`, `uv.lock`, `poetry.lock`, `Pipfile.lock`, `environment.yml`.
   - Version hints: `.nvmrc`, `.node-version`, `engines.node`, `.python-version`, `runtime.txt`, `requires-python`.
   - Entrypoints and checks: README setup steps, scripts, Makefile targets, CI workflows, Dockerfiles, Compose files, test config, lint/typecheck config.
   - Runtime needs: ports, databases, Redis, queues, browsers, native packages, OS libraries, private registries, required environment variables.
2. Select the simplest reproducible shape:
   - Use `.devcontainer/devcontainer.json` as the default location.
   - Use an official `mcr.microsoft.com/devcontainers/...` image when it already covers the runtime.
   - Check the official Dev Container Features catalog when adding portable tools such as GitHub CLI, Node, Python, Docker-in-Docker, or common CLIs: https://containers.dev/features
   - Check the official Dev Container Templates catalog when a repo closely matches a standard stack, but adapt the result to the repo instead of copying a generic template wholesale: https://containers.dev/templates
   - Add `.devcontainer/Dockerfile` only for apt packages, browser/system libraries, native build dependencies, or tools that should be cached in the image.
   - Use Docker Compose when the repo already depends on app-adjacent services or has a working compose setup. Keep the development service alive with a sleep loop if its normal command exits.
   - For AI-agent-facing containers that need restricted egress, read `references/networking.md` and adapt `templates/egress-proxy/`, which uses Squid as the bundled default proxy implementation.
3. Preserve repo conventions:
   - Use the package manager and install mode implied by the lockfile.
   - Configure `postCreateCommand` or an equivalent lifecycle command so dependencies are installed before the user starts development.
   - Keep the interactive development user non-root, normally the devcontainer image's `vscode` user. Do not set `remoteUser`, Compose `user`, or app/lifecycle commands to `root` unless the repo has a documented requirement and the risk is explained.
   - Use the runtime version implied by repo files; if no version is discoverable, choose the current stable official devcontainer image and note the assumption.
   - Do not replace existing Docker/Compose semantics unless they are clearly unsuitable for development.
4. Add VS Code customizations:
   - Always include `OpenAI.chatgpt` in `customizations.vscode.extensions`.
   - Add stack-specific extensions only when they clearly improve first-open use, such as `dbaeumer.vscode-eslint`, `esbenp.prettier-vscode`, `ms-python.python`, `ms-python.vscode-pylance`, or `ms-python.black-formatter`.
5. Handle secrets safely:
   - Never write secret values into committed files.
   - If a variable is required, document it with `secrets` in `devcontainer.json` or with a committed `.env.example` only when the repo already uses that convention.
   - Use `remoteEnv` or `containerEnv` only for non-secret defaults.
6. Validate before handoff:
   - Read `references/validation.md`.
   - Build and start the dev container when Docker/devcontainer tooling is available.
   - Run the repo's install, checks, and start smoke test inside the container.
   - Do not claim the setup is ready if the container builds but project dependencies, tests, or documented start commands fail. Report the exact blocker and remaining command.

## Reference Selection

- Read `references/node-typescript.md` for JavaScript, TypeScript, Node, frontend, or full-stack Node repos.
- Read `references/python.md` for Python apps, packages, notebooks, APIs, or data projects.
- Read `references/networking.md` when the setup needs Codespaces port behavior, Docker Compose service networking, or AI-agent-safe outbound network controls.
- Read `references/validation.md` for every task before final handoff.
- Use https://containers.dev/features to find current feature IDs and versions when a feature is better than a custom Dockerfile install.
- Use https://containers.dev/templates to find official/community templates for comparison, then keep only the parts that fit the target repo.

## Output Expectations

Create or update the minimum necessary files, usually:

- `.devcontainer/devcontainer.json`
- `.devcontainer/Dockerfile` only when needed
- `.devcontainer/docker-compose.yml` or Compose overrides only when needed
- `.devcontainer/squid.conf` only when adapting the bundled Squid egress-proxy template
- `.env.example` only when the repo convention supports it and no secrets are included

In the final response, list the files changed, validation commands run, and any remaining limitation. If validation could not run because Docker or the Dev Container CLI is unavailable, say that plainly and include the exact commands the user should run.
