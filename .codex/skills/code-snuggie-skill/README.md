# Code Snuggie

![Code Snuggie character](assets/small-code-snuggie-character-no-bg.png)

`code-snuggie` is an agent skill for creating reliable GitHub Codespaces and Dev Containers setups for existing repositories.

Use it when you want an agent to inspect a repo and add or repair `.devcontainer/devcontainer.json`, `.devcontainer/Dockerfile`, Docker Compose files, or related configuration so a user can open a codespace and start development with dependencies already installed.

## Contents

- `SKILL.md`: Main skill workflow and trigger description.
- `references/node-typescript.md`: Node.js, TypeScript, frontend, backend, browser, media, and monorepo guidance.
- `references/python.md`: Python app, package, notebook, browser, media, data, and native dependency guidance.
- `references/networking.md`: Port forwarding, Compose service networking, and restricted egress guidance.
- `references/validation.md`: Required validation gate before handing off a devcontainer setup.
- `templates/egress-proxy/`: Docker Compose + pinned Squid starting point for default-deny outbound networking in generated AI-agent-facing Codespaces.
- Dev Container Features catalog: https://containers.dev/features
- Dev Container Templates catalog: https://containers.dev/templates

## Expected Behavior

The skill should guide an AI agent to:

- Match the repo's existing runtime, package manager, lockfiles, scripts, services, and docs.
- Always include the OpenAI VS Code extension: `OpenAI.chatgpt`.
- Install dependencies automatically on first codespace open using `postCreateCommand` or an equivalent lifecycle command.
- Add practical development tools when the repo needs them, such as browser dependencies, `ffmpeg`, native build libraries, database clients, or geospatial libraries.
- Use restricted egress by default for generated AI-agent-facing Codespaces, with documented exceptions only when validation proves the allowlist is not yet viable.
- Validate the devcontainer build, startup, dependency install, project checks, and app start command before claiming the setup is ready.

## Example Prompt

```text
Use $code-snuggie to evaluate this repo and create a working Codespaces devcontainer setup.
```
