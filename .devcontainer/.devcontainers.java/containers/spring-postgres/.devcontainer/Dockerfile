# Use the official Ubuntu base image with version 22.04 (Jammy Jellyfish)
FROM ubuntu:jammy

# Install dependencies
RUN apt-get update \
&& apt-get install -y \
    git \
    libicu-dev \
    libpq-dev \
    libzip-dev \
    unzip \
    wget \
    zip \
    curl \
&& apt-get clean \
&& rm -rf /var/lib/apt/lists/*

# Switch to root user
USER root

# Set Java version to install
ENV JAVA_VERSION=17.0.12.fx-zulu
ENV SDKMAN_DIR=/usr/local/sdkman

# Install Java and necessary tools
RUN curl -fsSL "https://get.sdkman.io" | bash \
    && bash -c "source $SDKMAN_DIR/bin/sdkman-init.sh \
    && sdk install java ${JAVA_VERSION} \
    && sdk default java ${JAVA_VERSION}"

# Set JAVA_HOME and update PATH
ENV JAVA_HOME=$SDKMAN_DIR/candidates/java/current
ENV PATH=$JAVA_HOME/bin:$PATH
