# Node and TypeScript Dev Containers

Use this reference for JavaScript, TypeScript, Node.js, frontend, backend, and full-stack repos.

## Detection

Inspect these files before writing config:

- Package manager: `package-lock.json` means npm, `pnpm-lock.yaml` means pnpm, `yarn.lock` means Yarn, `bun.lock` or `bun.lockb` means Bun. Check `packageManager` in `package.json`; it may require Corepack.
- Runtime version: `.nvmrc`, `.node-version`, `.tool-versions`, `package.json` `engines.node`, CI setup, Dockerfile `FROM node:...`.
- Monorepo shape: `workspaces`, `pnpm-workspace.yaml`, `turbo.json`, `nx.json`, `lerna.json`, multiple apps under `apps/` or `packages/`.
- Frameworks and ports: Next.js `next` usually `3000`, Vite `5173`, Astro `4321`, Remix/React Router often `3000`, Express/Nest/Fastify commonly `3000` or configured in env, Storybook `6006`.
- Native/browser/media needs: `sharp`, `canvas`, `node-gyp`, `sqlite3`, `better-sqlite3`, `playwright`, `puppeteer`, Cypress, Prisma, database clients, `fluent-ffmpeg`, `ffmpeg`, video/audio processing scripts.
- Service needs: Postgres, MySQL, Redis, Elasticsearch, localstack, queues, object storage; check compose files and env examples.

## Container Choice

Prefer an image-only config when the repo only needs Node plus normal package install:

```jsonc
{
  "name": "Node.js",
  "image": "mcr.microsoft.com/devcontainers/javascript-node:1-22-bookworm"
}
```

Use a Dockerfile when apt packages or browser dependencies are needed:

```jsonc
{
  "name": "Node.js",
  "build": {
    "dockerfile": "Dockerfile"
  }
}
```

Example Dockerfile:

```Dockerfile
FROM mcr.microsoft.com/devcontainers/javascript-node:1-22-bookworm

RUN apt-get update \
    && export DEBIAN_FRONTEND=noninteractive \
    && apt-get -y install --no-install-recommends \
      build-essential \
      python3 \
      pkg-config \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*
```

## Development Tools

Include tools that make the detected project work well in development. Do not keep the image artificially bare if the project clearly needs browser automation, media processing, native compilation, or database CLIs to run tests and local workflows.

Add tools based on repo evidence:

- Browser projects with Puppeteer, Playwright, Cypress, screenshot tests, PDF rendering, or browser-based scraping: install the required browsers/system libraries. Prefer the tool's documented install command when it is repo-specific.
- Puppeteer projects: ensure Chromium can run in the container. If relying on Puppeteer's bundled browser, install system libraries it needs; if using distro Chromium, set the repo's expected executable path without hardcoding secrets.
- Playwright projects: run the package manager install first, then `npx playwright install --with-deps` or the equivalent package-manager command.
- Video/audio projects using `ffmpeg`, `fluent-ffmpeg`, waveform generation, transcoding, thumbnails, or media metadata: install `ffmpeg` in the Dockerfile.
- Image/native projects using `sharp`, `canvas`, `node-gyp`, SQLite, or similar native modules: include `build-essential`, `python3`, `pkg-config`, and the specific development libraries the package documents.
- Database-backed apps: include only helpful client CLIs when they support normal dev workflows, such as `postgresql-client` for Postgres or `default-mysql-client` for MySQL.

Example media/browser Dockerfile additions:

```Dockerfile
RUN apt-get update \
    && export DEBIAN_FRONTEND=noninteractive \
    && apt-get -y install --no-install-recommends \
      ffmpeg \
      chromium \
      fonts-liberation \
      libasound2 \
      libatk-bridge2.0-0 \
      libgtk-3-0 \
      libnss3 \
      libxss1 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*
```

Prefer the narrowest set of packages that satisfies the repo's workflows, but include every package needed for install, test, build, and the documented dev server to work on first open.

Add Playwright dependencies only when the repo uses Playwright. Run the project's install command before installing browsers:

```jsonc
"postCreateCommand": "npm ci && npx playwright install --with-deps"
```

If the repo uses `corepack`, enable it explicitly:

```jsonc
"postCreateCommand": "corepack enable && pnpm install --frozen-lockfile"
```

If `package.json` has `packageManager`, activate that exact manager before install:

```jsonc
"postCreateCommand": "corepack enable && corepack prepare pnpm@9.12.3 --activate && pnpm install --frozen-lockfile"
```

## Install Commands

The container should be ready to start development when the user opens the codespace. Put the dependency install in `postCreateCommand` or an equivalent lifecycle command so the first open installs dependencies automatically. Do not leave dependency installation as a manual follow-up unless the install requires private credentials that are unavailable.

Choose exactly one primary install command:

- npm with `package-lock.json`: `npm ci`
- npm without lockfile: `npm install`
- pnpm with lockfile: `corepack enable && corepack prepare <packageManager-version> --activate && pnpm install --frozen-lockfile` when `packageManager` is present, otherwise `corepack enable && pnpm install --frozen-lockfile`
- pnpm without lockfile: `corepack enable && pnpm install`
- Yarn Berry with `.yarnrc.yml` or `packageManager`: `corepack enable && corepack prepare <packageManager-version> --activate && yarn install --immutable` when `packageManager` is present, otherwise `corepack enable && yarn install --immutable`
- Yarn Classic with `yarn.lock`: `yarn install --frozen-lockfile`
- Bun: use a Bun feature or Dockerfile install, then `bun install --frozen-lockfile` when a lockfile exists

Do not run `npm install` in a pnpm or Yarn repo. Do not remove lockfiles or switch package managers. If install depends on private registry credentials, configure a Codespaces secret or documented secret prompt and make the failure mode explicit.

## devcontainer.json Pattern

Include only ports that are likely to be used:

```jsonc
{
  "name": "Project Dev",
  "image": "mcr.microsoft.com/devcontainers/javascript-node:1-22-bookworm",
  "features": {
    "ghcr.io/devcontainers/features/github-cli:1": {}
  },
  "forwardPorts": [3000],
  "portsAttributes": {
    "3000": {
      "label": "app",
      "onAutoForward": "notify"
    }
  },
  "postCreateCommand": "npm ci",
  "customizations": {
    "vscode": {
      "extensions": [
        "OpenAI.chatgpt",
        "dbaeumer.vscode-eslint",
        "esbenp.prettier-vscode"
      ]
    }
  }
}
```

For monorepos, run the install command from the package-manager workspace root: the directory that contains the shared lockfile and workspace config such as `pnpm-lock.yaml`, `yarn.lock`, `package-lock.json`, `pnpm-workspace.yaml`, or the root `package.json` `workspaces` field. This is about the repo directory, not the Linux `root` user. Add a `postAttachCommand` only when the repo has a clear default dev command and it is safe to run automatically; otherwise document the start command in final output. Dependencies must still be installed by `postCreateCommand`.

## Services

Use Compose when the repo needs a database or cache at first open. Keep service names aligned with existing env defaults:

```jsonc
{
  "name": "Node.js + Postgres",
  "dockerComposeFile": "docker-compose.yml",
  "service": "app",
  "workspaceFolder": "/workspace",
  "shutdownAction": "stopCompose",
  "postCreateCommand": "npm ci",
  "customizations": {
    "vscode": {
      "extensions": ["OpenAI.chatgpt", "dbaeumer.vscode-eslint"]
    }
  }
}
```

For the app service command in Compose:

```yaml
command: sleep infinity
volumes:
  - ..:/workspace:cached
```

Do not expose database credentials as real secrets. Use local development defaults only.

## Validation Commands

After `devcontainer up`, run checks inside the container with `devcontainer exec --workspace-folder . ...`:

- Verify dependencies are installed by `postCreateCommand`; re-run the chosen install command inside the container if necessary and fix the lifecycle command if it fails.
- Typecheck: prefer `npm run typecheck`, `pnpm typecheck`, or `yarn typecheck` if present.
- Lint: prefer `npm run lint`, `pnpm lint`, or `yarn lint` if present.
- Test: prefer `npm test`, `pnpm test`, or `yarn test`; add CI flags only if the repo already uses them.
- Build: prefer `npm run build`, `pnpm build`, or `yarn build` if present.
- Start smoke: run the documented dev command long enough to verify it binds the forwarded port. Stop it afterward.

If a check is absent, do not invent it. Use the scripts and CI config the repo already has.
