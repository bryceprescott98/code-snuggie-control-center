# Python Dev Containers

Use this reference for Python apps, packages, APIs, notebooks, data projects, and Python services.

## Detection

Inspect these files before writing config:

- Project metadata: `pyproject.toml`, `setup.py`, `setup.cfg`, `requirements*.txt`, `environment.yml`, `Pipfile`, `poetry.lock`, `uv.lock`.
- Runtime version: `.python-version`, `runtime.txt`, `requires-python`, CI setup, Dockerfile `FROM python:...`.
- Package manager: uv from `uv.lock` or `pyproject.toml` docs, Poetry from `poetry.lock` or `[tool.poetry]`, Pipenv from `Pipfile.lock`, Conda from `environment.yml`, plain pip from requirements files.
- App frameworks and ports: Flask often `5000`, FastAPI/Uvicorn often `8000`, Django often `8000`, Jupyter `8888`, Streamlit `8501`, Gradio `7860`.
- Native/system/media needs: `psycopg2`, `mysqlclient`, `lxml`, `Pillow`, `opencv-python`, `weasyprint`, `cryptography`, `scipy`, `torch`, `playwright`, Selenium/browser automation, `ffmpeg-python`, movie/audio processing, GDAL/geospatial packages.
- Service needs: Postgres, MySQL, Redis, localstack, vector databases, workers, task queues; check Compose files and env examples.

## Container Choice

Prefer the official Python devcontainer image:

```jsonc
{
  "name": "Python",
  "image": "mcr.microsoft.com/devcontainers/python:1-3.12-bookworm"
}
```

Use a Dockerfile when system libraries are required:

```Dockerfile
FROM mcr.microsoft.com/devcontainers/python:1-3.12-bookworm

RUN apt-get update \
    && export DEBIAN_FRONTEND=noninteractive \
    && apt-get -y install --no-install-recommends \
      build-essential \
      pkg-config \
      libpq-dev \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*
```

Pin the Python image variant to the repo's declared Python version when discoverable. If the repo allows a range, choose the newest stable version inside the supported range.

## Development Tools

Include tools that make the detected project work well in development. Do not keep the image artificially bare if the project clearly needs browser automation, media processing, native compilation, geospatial libraries, or database CLIs to run tests and local workflows.

Add tools based on repo evidence:

- Browser automation with Playwright, Selenium, browser scraping, screenshot tests, or PDF rendering: install browser/system dependencies. For Playwright, run the Python package install first, then `python -m playwright install --with-deps` when Playwright is a dependency.
- Video/audio projects using `ffmpeg-python`, MoviePy, OpenCV video, transcription preprocessing, waveform generation, thumbnails, or media metadata: install `ffmpeg` in the Dockerfile.
- Image/PDF projects using Pillow, OpenCV, WeasyPrint, Cairo, or report generation: install the documented system libraries such as `libgl1`, `libglib2.0-0`, `libcairo2`, `pango`, or font packages as needed.
- Database-backed apps: include helpful client libraries and CLIs when they support normal dev workflows, such as `libpq-dev` and `postgresql-client` for Postgres or `default-libmysqlclient-dev` and `default-mysql-client` for MySQL.
- Geospatial/data science projects: include GDAL/GEOS/PROJ or BLAS/OpenMP libraries only when dependencies require them.
- Native extension projects: include `build-essential`, `pkg-config`, and Python headers or library-specific dev packages required by the dependency docs.

Example media/browser/data Dockerfile additions:

```Dockerfile
RUN apt-get update \
    && export DEBIAN_FRONTEND=noninteractive \
    && apt-get -y install --no-install-recommends \
      build-essential \
      pkg-config \
      ffmpeg \
      libgl1 \
      libglib2.0-0 \
      libpq-dev \
      postgresql-client \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*
```

Prefer the narrowest set of packages that satisfies the repo's workflows, but include every package needed for install, test, build, and the documented dev server or notebook workflow to work on first open.

## Install Commands

The container should be ready to start development when the user opens the codespace. Put the dependency install in `postCreateCommand` or an equivalent lifecycle command so the first open installs dependencies automatically. Do not leave dependency installation as a manual follow-up unless the install requires private credentials that are unavailable.

Choose exactly one primary install flow:

- uv with `uv.lock`: `uv sync --frozen`
- uv without lockfile: `uv sync`
- Poetry with lockfile: `poetry install --no-interaction --no-root` for apps, or omit `--no-root` for packages that must install themselves
- Pipenv: `pipenv install --dev --deploy`
- Conda: `conda env update -f environment.yml`
- requirements only: `pip install --user -r requirements.txt`
- requirements plus dev file: `pip install --user -r requirements.txt -r requirements-dev.txt`
- package project with extras: `pip install --user -e ".[dev]"`

For uv, prefer installing it in the Dockerfile unless the repo already uses a verified Dev Container Feature reference. Do not invent an official `ghcr.io/devcontainers/features/uv` feature; current `uv` features are community-published and should be checked before use.

```Dockerfile
RUN curl -LsSf https://astral.sh/uv/install.sh | UV_INSTALL_DIR=/usr/local/bin sh
```

Use root only for image-build steps that genuinely require it, such as OS package installation or placing a shared tool in `/usr/local/bin`. The interactive devcontainer user and lifecycle commands should run as the non-root `vscode` user when possible. If install depends on private package indexes or credentials, configure a Codespaces secret or documented secret prompt and make the failure mode explicit.

## devcontainer.json Pattern

```jsonc
{
  "name": "Python Dev",
  "image": "mcr.microsoft.com/devcontainers/python:1-3.12-bookworm",
  "features": {
    "ghcr.io/devcontainers/features/github-cli:1": {}
  },
  "forwardPorts": [8000],
  "portsAttributes": {
    "8000": {
      "label": "app",
      "onAutoForward": "notify"
    }
  },
  "postCreateCommand": "pip install --user -r requirements.txt",
  "customizations": {
    "vscode": {
      "extensions": [
        "OpenAI.chatgpt",
        "ms-python.python",
        "ms-python.vscode-pylance"
      ]
    }
  }
}
```

For Flask, include `FLASK_RUN_HOST=0.0.0.0` as a non-secret `containerEnv` only if it matches the documented run command. For Django/FastAPI, ensure the documented command binds to `0.0.0.0`, not only `127.0.0.1`, when users need browser access from Codespaces. Dependencies must be installed by `postCreateCommand` before the user starts development.

## Services

Use Compose for databases/caches required at first open. Align hostnames with service names and env examples:

```yaml
services:
  app:
    build:
      context: .
      dockerfile: Dockerfile
    command: sleep infinity
    volumes:
      - ..:/workspace:cached
    depends_on:
      - db
  db:
    image: postgres:16
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
      POSTGRES_DB: app
```

Use local development credentials only. If the app needs private API keys, configure `secrets` prompts instead of defaults.

## Validation Commands

After `devcontainer up`, run checks inside the container with `devcontainer exec --workspace-folder . ...`:

- Verify Python: `python --version` and compare to the repo's declared range.
- Verify dependencies are installed by `postCreateCommand`; re-run the selected install command inside the container if necessary and fix the lifecycle command if it fails.
- Test: `pytest`, `python -m pytest`, or the repo's Make/tox/nox command when present.
- Lint/format: `ruff check .`, `flake8`, `black --check .`, or repo scripts only when configured.
- Typecheck: `mypy`, `pyright`, or repo scripts only when configured.
- Build package: `python -m build` only when the repo is a package and has build config.
- Start smoke: run the documented Flask/FastAPI/Django/Jupyter/Streamlit command long enough to verify it binds the forwarded port. Stop it afterward.

Do not invent missing test or lint tools. Prefer CI workflow commands when they exist.
