# Dev Container Networking

Use this reference when configuring forwarded ports, Docker Compose services, or restricted egress for an AI-agent-facing devcontainer.

## Port Access

- Prefer `forwardPorts` and `portsAttributes` in `devcontainer.json`; do not publish broad host ports unless the repo already requires them.
- Make web servers bind to `0.0.0.0` inside the container when they must be reachable through forwarded ports.
- Forward the app's container port, not a random host port.
- Label forwarded ports so Codespaces and VS Code show useful names.

## Compose Service Networking

- In Compose, app code should reach dependencies by service name, such as `db:5432` or `redis:6379`.
- Keep local service credentials development-only and non-secret.
- Do not use `network_mode: host` for normal devcontainer networking.
- If the app service's normal command exits, use `command: sleep infinity` for the devcontainer service.

## Restricted Egress

For AI-agent-facing workspaces, prefer a proxy/firewall sidecar over in-container firewall rules. The stronger pattern is:

```text
devcontainer on internal network -> egress proxy/firewall -> small allowlist -> internet
```

Use `templates/egress-proxy/` when the user asks for restricted networking or when the repo's threat model calls for default-deny outbound access. The template uses Squid because it is a mature forward proxy with domain allowlists and access logs. If the target environment already provides a stronger egress gateway, host firewall, or managed network policy, use that instead and keep the same allowlist principles.

Keep the allowlist repo-specific. Start with only the domains needed for the detected stack:

- GitHub: `github.com`, `api.github.com`, `raw.githubusercontent.com`, `objects.githubusercontent.com`
- Node: `registry.npmjs.org`
- Python: `pypi.org`, `files.pythonhosted.org`
- Rust: `crates.io`, `static.crates.io`, `index.crates.io`
- Go: `proxy.golang.org`, `sum.golang.org`
- VS Code/devcontainers: `marketplace.visualstudio.com`, `update.code.visualstudio.com`, `vscode.blob.core.windows.net`
- AI APIs only when needed: `api.openai.com`, `api.anthropic.com`

Avoid broad entries such as `*.githubusercontent.com`, `*.amazonaws.com`, `*.cloudfront.net`, `*.googleapis.com`, `0.0.0.0/0`, RFC1918 private networks, or `169.254.169.254` unless the repo explicitly needs them.

## Setup vs Agent Runtime

Dependency installation may need broader network access than day-to-day agent work. If strict egress blocks first-open setup, separate the phases:

- Allow setup/install domains during build or `postCreateCommand`.
- Tighten runtime egress before agent work begins.
- Document any required manual approval when the safe allowlist is insufficient.

## Bypass Checks

Avoid these unless the user explicitly requests and accepts the risk:

- `privileged: true`
- `--privileged`
- `--network=host`
- `network_mode: host`
- Mounting `/var/run/docker.sock`
- Mounting host `~/.ssh`, cloud credentials, or production secrets
- Publishing large port ranges
