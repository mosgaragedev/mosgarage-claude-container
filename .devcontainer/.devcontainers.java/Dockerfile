# .devcontainer/Dockerfile
# ============================================
# Stage 1: Base image + system dependencies
# ============================================
ARG NODE_VERSION=22
FROM mcr.microsoft.com/devcontainers/javascript-node:${NODE_VERSION} AS base

ARG PYTHON_VERSION=3.12
RUN apt-get update && apt-get install -y --no-install-recommends \
    python${PYTHON_VERSION} \
    python${PYTHON_VERSION}-venv \
    python3-pip \
    build-essential \
    libcairo2-dev \
    libpango1.0-dev \
    libjpeg-dev \
    libgif-dev \
    librsvg2-dev \
    && rm -rf /var/lib/apt/lists/*

# Create Python virtual environment
RUN python${PYTHON_VERSION} -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# ============================================
# Stage 2: Dependency installation
# ============================================
FROM base AS deps

WORKDIR /workspace
COPY package.json package-lock.json ./
RUN npm ci --prefer-offline

COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

# ============================================
# Stage 3: Development environment (final image)
# ============================================
FROM base AS development

# Copy node_modules from deps stage
COPY --from=deps /workspace/node_modules /workspace/node_modules
COPY --from=deps /opt/venv /opt/venv

# Set up zsh + oh-my-zsh
RUN apt-get update && apt-get install -y zsh \
    && sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended \
    && rm -rf /var/lib/apt/lists/*

# Developer convenience tools
RUN npm install -g \
    typescript \
    tsx \
    @biomejs/biome \
    turbo

WORKDIR /workspace
ENV NODE_ENV=development
