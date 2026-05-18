# Dev Container Validation Gate

Run this reference before handing off any Codespaces/devcontainer setup. A devcontainer that builds but cannot install dependencies, run checks, or start the app is not complete.

## Static Checks

1. Confirm files are in the expected location:
   - Preferred: `.devcontainer/devcontainer.json`
   - Optional only when needed: `.devcontainer/Dockerfile`, `.devcontainer/docker-compose.yml`, `.devcontainer/compose.yaml`
2. Confirm `devcontainer.json` is JSONC-compatible and has one valid container source:
   - `image`, or
   - `build.dockerfile`, or
   - `dockerComposeFile` plus `service`.
3. Confirm `customizations.vscode.extensions` contains `OpenAI.chatgpt`.
4. Confirm lifecycle commands are repo-aware:
   - `postCreateCommand` installs dependencies using the repo's package manager.
   - Commands do not require interactive input.
   - Commands do not write secrets.
   - Commands run as the non-root development user, not as `root`.
5. Confirm no template placeholders remain, such as `<repo-install-command>` or generic copied names.
6. Confirm ports match actual app commands and include useful `portsAttributes` labels.
7. Confirm networking does not include avoidable bypasses:
   - No `--network=host` or `network_mode: host`.
   - No `--privileged` or `privileged: true` unless explicitly required.
   - No Docker socket mount unless Docker control is required and the risk is documented.
   - No host SSH keys, cloud credentials, or production secrets mounted into the container.
   - No broad host port ranges published when `forwardPorts` is sufficient.
8. Confirm secrets are not committed:
   - No real tokens, passwords, cloud keys, or private registry credentials.
   - Required secret names appear in `secrets` or documentation only.
9. Confirm the interactive container user is non-root:
   - Prefer the official devcontainer image default, usually `vscode`.
   - Do not set `remoteUser`, Compose `user`, `containerUser`, or app service commands to `root` unless a repo-specific need is documented.
   - Root is acceptable for Dockerfile image-build steps such as `apt-get install`; it is not acceptable as the default user for normal development, dependency installs, tests, or app commands.

## CLI Validation

Use the Dev Container CLI when available:

```bash
devcontainer read-configuration --workspace-folder .
devcontainer build --workspace-folder .
devcontainer up --workspace-folder .
```

Then run project checks inside the created container:

```bash
devcontainer exec --workspace-folder . <install-or-verify-command>
devcontainer exec --workspace-folder . <test-command>
devcontainer exec --workspace-folder . <build-or-typecheck-command>
```

Use only commands discovered from manifests, scripts, README, Makefiles, or CI.

## Dockerfile Validation

If `.devcontainer/Dockerfile` exists, build it directly as a fast syntax/cache check:

```bash
docker build -f .devcontainer/Dockerfile .devcontainer
```

If the Dockerfile needs the repo root as build context, use the context configured in `devcontainer.json` instead:

```bash
docker build -f .devcontainer/Dockerfile .
```

Common blockers to fix before handoff:

- Missing `apt-get update` before `apt-get install`.
- Apt cache not cleaned in long-lived custom images.
- Package installs that prompt for input because `DEBIAN_FRONTEND=noninteractive` is missing.
- Dockerfile assumes workspace files are available during image build when the devcontainer build context is `.devcontainer`.
- Installing developer tools into root-owned locations, then running lifecycle commands as `vscode` without PATH or permission handling.

## Docker Compose Validation

If Compose is used:

```bash
docker compose -f .devcontainer/docker-compose.yml config
docker compose -f .devcontainer/docker-compose.yml build
```

If the devcontainer references multiple Compose files, pass every file in the same order as `dockerComposeFile`.

Check:

- `service` in `devcontainer.json` matches a Compose service.
- `workspaceFolder` matches the bind mount target.
- The app service has `command: sleep infinity` or another long-running development command.
- App code reaches dependencies by Compose service name, not `localhost`.
- Required dependent services have local development defaults.
- `shutdownAction` is usually `stopCompose`.
- Restricted egress setups use an internal app network plus a proxy/firewall sidecar, and the allowlist is repo-specific.

## In-Container Project Validation

Run the repo's own checks inside the dev container:

- Dependency install or lockfile verification.
- Unit tests or the closest CI test command.
- Typecheck/lint/build when configured.
- A start smoke test for the documented app command.

For web apps, verify the command binds to `0.0.0.0` and the forwarded port appears. A process listening only on `127.0.0.1` inside the container may not be reachable as expected from Codespaces.

## Handoff Rule

Mark the setup ready only when:

- Static validation passes.
- `devcontainer read-configuration`, `build`, and `up` pass, or unavailable tooling is explicitly reported.
- Dockerfile/Compose validation passes when those files exist.
- In-container dependency install and repo checks pass.
- Any untested step is documented with the exact command and reason it could not be run.

If any required command fails, fix the config and rerun validation. If the failure is a pre-existing project issue, capture the failing command, relevant output, and why the devcontainer itself is still correct.
