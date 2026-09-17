# Use Node.js 20 LTS as the base image
FROM node:20-alpine

# Install other dependencies as before
RUN apk add --no-cache \
    bash \
    git \
    openjdk17 \
    libpq

# Set the JAVA_HOME environment variable correctly
ENV JAVA_HOME=/usr/lib/jvm/java-17-openjdk
ENV PATH=$JAVA_HOME/bin:$PATH
