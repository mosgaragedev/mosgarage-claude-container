# ╔══════════════════════════════════════════════════════════════════╗
# ║  mosgarage · Dockerfile                                          ║
# ║  Stage 1: dotnet build   Stage 2: node assets                   ║
# ║  Stage 3: runtime (ASP.NET 8 on Ubuntu Chiselled)               ║
# ╚══════════════════════════════════════════════════════════════════╝

# ── Stage 1: .NET build ────────────────────────────────────────────
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS dotnet-build
WORKDIR /src

# Restore — cached layer
COPY src/Mosgarage.Shared/Mosgarage.Shared.csproj  src/Mosgarage.Shared/
COPY src/Mosgarage.Server/Mosgarage.Server.csproj  src/Mosgarage.Server/
COPY src/Mosgarage.Agent/Mosgarage.Agent.csproj    src/Mosgarage.Agent/
COPY Mosgarage.sln                                  .
RUN dotnet restore Mosgarage.sln

# Copy source and build
COPY src/ src/
RUN dotnet publish src/Mosgarage.Server/Mosgarage.Server.csproj \
    -c Release -o /app/server --no-restore \
    /p:UseAppHost=false

RUN dotnet publish src/Mosgarage.Agent/Mosgarage.Agent.csproj \
    -c Release -o /app/agent --no-restore \
    /p:UseAppHost=false

# ── Stage 2: Node.js frontend assets ──────────────────────────────
FROM node:20-alpine AS node-build
WORKDIR /ui

COPY src/Mosgarage.Server/ClientApp/package*.json ./
RUN npm ci --prefer-offline

COPY src/Mosgarage.Server/ClientApp/ .
RUN npm run build

# ── Stage 3: Runtime (Ubuntu Chiselled — minimal attack surface) ──
FROM mcr.microsoft.com/dotnet/aspnet:8.0-jammy-chiseled AS runtime

LABEL org.opencontainers.image.title="mosgarage"
LABEL org.opencontainers.image.description="mosgarage control plane — .NET 8"
LABEL org.opencontainers.image.source="https://github.com/mosgarage/mosgaragedev"
LABEL org.opencontainers.image.vendor="mosgarage"

# Switch to root for setup, then drop back
USER root

# Install runtime tools
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    git \
    openssh-client \
    openssh-server \
    ca-certificates \
    inotify-tools \
    && rm -rf /var/lib/apt/lists/*

# Create user
RUN groupadd -g 1001 mosgarage && \
    useradd  -u 1001 -g mosgarage -m -s /bin/bash -d /home/mosgarage mosgarage

# App dirs
RUN mkdir -p \
    /app/server \
    /app/agent \
    /home/mosgarage/templates \
    /home/mosgarage/state \
    /home/mosgarage/.ssh \
    /var/log/mosgarage \
    && chown -R mosgarage:mosgarage /app /home/mosgarage /var/log/mosgarage

# Copy built artefacts
COPY --from=dotnet-build  --chown=mosgarage:mosgarage /app/server /app/server
COPY --from=dotnet-build  --chown=mosgarage:mosgarage /app/agent  /app/agent
COPY --from=node-build    --chown=mosgarage:mosgarage /ui/dist    /app/server/wwwroot

# SSH config
COPY config/ssh/sshd_config          /etc/ssh/sshd_config
COPY config/ssh/mosgarage-banner.txt /etc/ssh/mosgarage-banner.txt

# Copy scripts
COPY --chown=root:root            scripts/ssh-setup.sh  /usr/local/bin/ssh-setup
COPY --chown=mosgarage:mosgarage scripts/startup.sh     /usr/local/bin/mosgarage-start
COPY --chown=mosgarage:mosgarage scripts/git-setup.sh   /usr/local/bin/git-setup
COPY --chown=mosgarage:mosgarage scripts/git-sync.sh    /usr/local/bin/git-sync
COPY --chown=mosgarage:mosgarage scripts/git-push-now.sh /usr/local/bin/git-push-now
COPY --chown=mosgarage:mosgarage scripts/git-status.sh  /usr/local/bin/git-status
RUN chmod +x \
    /usr/local/bin/ssh-setup \
    /usr/local/bin/mosgarage-start \
    /usr/local/bin/git-setup \
    /usr/local/bin/git-sync \
    /usr/local/bin/git-push-now \
    /usr/local/bin/git-status

USER mosgarage
WORKDIR /app/server

# ── Exposed ports ──────────────────────────────────────────────────
# 2222 → SSH server
#   7070 → control plane HTTP (API + UI + SignalR)
# 7071 → agent endpoint (workspace agents connect here)
EXPOSE 7070 7071 2222

ENV DOTNET_ENVIRONMENT=Production
ENV ASPNETCORE_URLS="http://+:7070;http://+:7071"

ENTRYPOINT ["/usr/local/bin/mosgarage-start"]


# ── Workspace image (provisioned dynamically) ──────────────────────
FROM ubuntu:22.04 AS workspace-base

LABEL org.opencontainers.image.title="mosgarage-workspace"
LABEL org.opencontainers.image.description="mosgarage managed workspace — code-server + Node + agent"

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl wget git openssh-client ca-certificates build-essential \
    python3 python3-pip unzip zip jq vim nano htop supervisor \
    inotify-tools net-tools && \
    rm -rf /var/lib/apt/lists/*

# Node.js 20 LTS
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get install -y nodejs && npm install -g npm@latest pm2 && \
    rm -rf /var/lib/apt/lists/*

# code-server
RUN curl -fsSL https://code-server.dev/install.sh | sh && \
    rm -rf /var/lib/apt/lists/*

# .NET runtime (for agent)
RUN curl -fsSL https://dot.net/v1/dotnet-install.sh | bash -s -- --runtime aspnetcore --channel 8.0 \
    --install-dir /usr/local/dotnet
ENV DOTNET_ROOT=/usr/local/dotnet
ENV PATH="$PATH:/usr/local/dotnet"

RUN apt-get update && apt-get install -y --no-install-recommends openssh-server && rm -rf /var/lib/apt/lists/*

RUN useradd -m -s /bin/bash -d /home/mosgarage mosgarage && \
    mkdir -p /home/mosgarage/{.config/code-server,.ssh,workspace} && \
    mkdir -p /var/log/mosgarage

COPY --from=dotnet-build --chown=mosgarage:mosgarage /app/agent /app/agent
COPY config/workspace-supervisord.conf /etc/supervisor/conf.d/workspace.conf
COPY config/ssh/sshd_config        /etc/ssh/sshd_config
COPY config/ssh/mosgarage-banner.txt /etc/ssh/mosgarage-banner.txt
COPY scripts/ssh-setup.sh          /usr/local/bin/ssh-setup
COPY scripts/workspace-startup.sh /usr/local/bin/workspace-start
RUN chmod +x /usr/local/bin/ssh-setup /usr/local/bin/workspace-start

EXPOSE 8080 3000 4000 7072 2222

USER mosgarage
WORKDIR /home/mosgarage/workspace
CMD ["/usr/local/bin/workspace-start"]
