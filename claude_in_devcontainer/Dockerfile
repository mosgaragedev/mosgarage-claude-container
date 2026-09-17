FROM node:20

ARG TZ
ENV TZ="$TZ"

ARG CLAUDE_CODE_VERSION=latest
ARG RUST_VERSION=1.82.0
ARG SWIPLDIR=/usr/lib/swi-prolog
ARG ALLOY_VERSION=6.2.0

# Install basic development tools and all language environments
RUN apt-get update && apt-get install -y --no-install-recommends \
  less \
  git \
  procps \
  sudo \
  fzf \
  zsh \
  man-db \
  unzip \
  gnupg2 \
  gh \
  iptables \
  ipset \
  iproute2 \
  dnsutils \
  aggregate \
  jq \
  nano \
  vim \
  curl \
  wget \
  build-essential \
  pkg-config \
  libssl-dev \
  python3 \
  python3-pip \
  python3-venv \
  swi-prolog \
  openjdk-17-jre-headless \
  && apt-get clean && rm -rf /var/lib/apt/lists/*

# Ensure default node user has access to /usr/local/share
RUN mkdir -p /usr/local/share/npm-global && \
  chown -R node:node /usr/local/share

ARG USERNAME=node

# Install Rust and Python tools as the node user
USER mosgarage

# Install Rust toolchain
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain ${RUST_VERSION}
ENV PATH="/home/node/.cargo/bin:${PATH}"

# Install uv (fast Python package installer)
RUN curl -LsSf https://astral.sh/uv/install.sh | sh

# Install ruff and mypy globally via uv
RUN /home/node/.local/bin/uv tool install ruff && \
    /home/node/.local/bin/uv tool install mypy

ENV PATH="/home/node/.local/bin:${PATH}"

# Switch back to root for remaining setup
USER root

# Persist bash history
RUN SNIPPET="export PROMPT_COMMAND='history -a' && export HISTFILE=/commandhistory/.bash_history" \
  && mkdir /commandhistory \
  && touch /commandhistory/.bash_history \
  && chown -R $USERNAME /commandhistory

# Set `DEVCONTAINER` environment variable to help with orientation
ENV DEVCONTAINER=true

# Create workspace and config directories and set permissions
RUN mkdir -p /workspace /home/node/.claude && \
  chown -R node:node /workspace /home/node/.claude

WORKDIR /workspace

# Install Alloy Analyzer
RUN wget -q "https://github.com/AlloyTools/org.alloytools.alloy/releases/download/v${ALLOY_VERSION}/org.alloytools.alloy.dist.jar" \
  -O /usr/local/lib/alloy.jar && \
  echo '#!/bin/bash' > /usr/local/bin/alloy && \
  echo 'exec java -jar /usr/local/lib/alloy.jar "$@"' >> /usr/local/bin/alloy && \
  chmod +x /usr/local/bin/alloy

# Install git-delta for better diffs
ARG GIT_DELTA_VERSION=0.18.2
RUN ARCH=$(dpkg --print-architecture) && \
  wget "https://github.com/dandavison/delta/releases/download/${GIT_DELTA_VERSION}/git-delta_${GIT_DELTA_VERSION}_${ARCH}.deb" && \
  dpkg -i "git-delta_${GIT_DELTA_VERSION}_${ARCH}.deb" && \
  rm "git-delta_${GIT_DELTA_VERSION}_${ARCH}.deb"

# Install zsh-in-docker
ARG ZSH_IN_DOCKER_VERSION=1.2.0
RUN wget "https://github.com/deluan/zsh-in-docker/releases/download/v${ZSH_IN_DOCKER_VERSION}/zsh-in-docker.sh" && \
  chmod +x zsh-in-docker.sh && \
  ./zsh-in-docker.sh \
    -t robbyrussell \
    -p git \
    -p ssh-agent \
    -p https://github.com/zsh-users/zsh-autosuggestions \
    -p https://github.com/zsh-users/zsh-completions && \
  rm zsh-in-docker.sh

# Install Claude Code CLI (as root for global install)
RUN npm install -g @anthropic-ai/claude-code@${CLAUDE_CODE_VERSION}

# Switch to node user for runtime
USER $USERNAME

# Set environment variables for Claude Code
ENV CLAUDE_CONFIG_DIR="/home/node/.claude"
ENV NODE_OPTIONS="--max-old-space-size=4096"

# Verify installations
RUN rustc --version && \
    cargo --version && \
    python3 --version && \
    uv --version && \
    ruff --version && \
    mypy --version && \
    swipl --version && \
    java -version && \
    claude --version
