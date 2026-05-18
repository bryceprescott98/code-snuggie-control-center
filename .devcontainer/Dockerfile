FROM mcr.microsoft.com/devcontainers/javascript-node:1-22-bookworm

RUN apt-get update \
    && export DEBIAN_FRONTEND=noninteractive \
    && apt-get -y install --no-install-recommends \
      ca-certificates \
      curl \
      git \
      jq \
      python3 \
      python3-pip \
      python3-venv \
    && npm install -g @devcontainers/cli \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*
