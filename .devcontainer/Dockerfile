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
      ripgrep \
    && npm install -g @devcontainers/cli \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /etc/docker \
    && printf '%s\n' \
      '{' \
      '  "features": {' \
      '    "containerd-snapshotter": false' \
      '  },' \
      '  "storage-driver": "overlay2"' \
      '}' \
      > /etc/docker/daemon.json

RUN id node
