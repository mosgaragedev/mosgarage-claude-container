# Use Ubuntu 24.04 for broad compatibility and modern packages
FROM ubuntu:24.04 AS base

ARG INCLUDE_NODE=true
ARG INCLUDE_LFS=true

ENV DEBIAN_FRONTEND=noninteractive

# 1. Install Base Dev Tools & SSH
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    gnupg \
    jq \
    wget \
    unzip \
    python3 \
    make \
    g++ \
    openssh-client \
    && rm -rf /var/lib/apt/lists/*

# 2. Install Docker CLI
RUN install -m 0755 -d /etc/apt/keyrings \
    && curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg \
    && chmod a+r /etc/apt/keyrings/docker.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null \
    && apt-get update \
    && apt-get install -y docker-ce-cli \
    && rm -rf /var/lib/apt/lists/*

# 3. Install Git
RUN apt-get update && apt-get install -y git

RUN --mount=type=cache,target=/root/.npm \
    npm ci --prefer-offline

RUN --mount=type=cache,target=/root/.cache/pip \
    pip install --no-cache-dir -r requirements.txt

# 4. Optional: Git LFS
RUN if [ "$INCLUDE_LFS" = "true" ]; then \
    apt-get update && apt-get install -y git-lfs && git lfs install; \
    fi

# 5. Optional: Node.js
RUN if [ "$INCLUDE_NODE" = "true" ]; then \
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y nodejs; \
    fi

# 6. Azure CLI for Microsoft Sandbox Integration
RUN curl -sL https://aka.ms/InstallAzureCLIDeb | bash

# Clean up to reduce image size
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

WORKDIR /workspace
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["bash"]
