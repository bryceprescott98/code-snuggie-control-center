# Tests

This directory contains test-only inputs and acceptance fixtures for the Code Snuggie Control Center.

- `fixtures/acceptance/remotion`: npm-starter fixture used to exercise generated workspace, restricted egress, and publish checks.
- `fixtures/acceptance/excalidraw`: GitHub/Yarn Classic fixture used to exercise repository job setup and summary checks.
- `fixtures/acceptance/unsafe-devcontainer`: negative fixture that must fail static devcontainer validation.

These are intentionally small representative projects, not reusable templates. Keep production guidance in `.codex/skills/code-snuggie-skill/` and update fixtures only when the acceptance tests need concrete sample workspaces.
