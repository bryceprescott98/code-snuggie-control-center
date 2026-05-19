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

Use `templates/egress-proxy/` for generated AI-agent-facing Codespaces unless the user explicitly accepts unrestricted egress in `VALIDATION.md`. The template uses Squid because it is a mature forward proxy with domain allowlists and access logs. If the target environment already provides a stronger egress gateway, host firewall, or managed network policy, use that instead and keep the same allowlist principles.

The bundled allowlist starts from GitHub's Copilot cloud agent recommended allowlist and adds OpenAI/ChatGPT domains needed for Codex authentication, API calls, and WebSocket streaming:

- GitHub Copilot allowlist: https://docs.github.com/en/copilot/reference/copilot-allowlist-reference
- OpenAI/ChatGPT network recommendations: https://help.openai.com/en/articles/9247338-network-recommendations-for-chatgpt-errors-on-web-and-apps

When adapting the template, keep the day-to-day allowlist repo-specific:

- Keep the common Codex/OpenAI, GitHub, certificate-authority, VS Code, and detected package-manager hosts.
- Remove ecosystems the project clearly does not use when tighter egress matters.
- Add project-specific domains only after validation proves they are needed.
- Prefer exact hostnames over broad wildcards. Some upstream allowlist entries are host/path URLs; Squid `dstdomain` can only enforce hostnames for HTTPS `CONNECT`, so reduce those entries to their hostname.
- Do not add the Copilot allowlist's IP-only entries such as Docker bridge gateways or cloud metadata service IPs to the Squid domain ACL by default. In a devcontainer, those can accidentally grant host or platform metadata reachability. Add them only with a documented repo-specific need and a separate `dst` ACL.

Avoid broad entries such as `*.amazonaws.com`, `*.cloudfront.net`, `*.googleapis.com`, `0.0.0.0/0`, RFC1918 private networks, or `169.254.169.254` unless the repo explicitly needs them and the reason is documented.

The proxy sidecar must stay on both networks while the devcontainer service stays only on the internal network:

```yaml
services:
  dev:
    environment:
      HTTP_PROXY: http://egress-proxy:3128
      HTTPS_PROXY: http://egress-proxy:3128
    networks:
      - devnet

  egress-proxy:
    image: ubuntu/squid:6.6-24.04_beta
    volumes:
      - ./squid.conf:/etc/squid/squid.conf:ro
    networks:
      - devnet
      - outbound

networks:
  devnet:
    internal: true
  outbound: {}
```

## Setup vs Agent Runtime

Dependency installation may need broader network access than day-to-day agent work. Prefer broad-but-explicit package-manager hosts over disabling the proxy. If strict egress blocks first-open setup, separate the phases:

- Allow setup/install domains during build or `postCreateCommand`.
- Tighten runtime egress before agent work begins.
- Document any required manual approval when the safe allowlist is insufficient.
- As a last resort, set `CODE_SNUGGIE_ALLOW_UNRESTRICTED_EGRESS=1` only for publishing a job whose `VALIDATION.md` explains why restricted egress is not viable yet and what would be needed to restore it.

## Bypass Checks

Avoid these unless the user explicitly requests and accepts the risk:

- `privileged: true`
- `--privileged`
- `--network=host`
- `network_mode: host`
- Mounting `/var/run/docker.sock`
- Mounting host `~/.ssh`, cloud credentials, or production secrets
- Publishing large port ranges
