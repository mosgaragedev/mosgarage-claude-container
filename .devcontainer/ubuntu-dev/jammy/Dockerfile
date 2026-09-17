FROM ubuntu:jammy


USER root
RUN (echo 'APT::Install-Suggests "0";' >> /etc/apt/apt.conf.d/00-docker)
RUN (echo 'APT::Install-Recommends "0";' >> /etc/apt/apt.conf.d/00-docker)
RUN (apt-get update)
RUN (apt-get install -y ssh expect)
RUN (apt-get install -y build-essential)
RUN (apt-get install -y software-properties-common)
RUN (apt-get update)
RUN (apt-get install -y wget \
                        openssl \
                        man-db \
                        git \
                        gdb \
                        manpages-dev \
                        manpages-posix \
                        manpages-posix-dev \
                        autoconf \
                        automake \
                        libtool \
                        libssl-dev \
                        libc6-dbg \
                        clang-format \
                        clang-11 \
                        clang-15 \
                        doxygen \
                        graphviz \
                        sudo \
                        dos2unix \
                        libxml2-utils)

# -----------------------------------------------------------------
# Create and configure users.
# -----------------------------------------------------------------

USER root
RUN (useradd -rm -d /home/dev -s /bin/bash -g root -G sudo -u 1000 dev)
RUN (echo 'dev:dev' | chpasswd)
RUN (echo 'root:root' | chpasswd)

# -----------------------------------------------------------------
# Configure SSH server.
# -----------------------------------------------------------------

USER root
RUN (ssh-keygen -A; \
     sed -i 's/UsePAM yes/#UsePAM yes/g' /etc/ssh/sshd_config; \
     sed -i 's/#PermitRootLogin yes/PermitRootLogin yes/' /etc/ssh/sshd_config; \
     sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config; \
     sed -iE 's/\s*#\s*PermitRootLogin .*/PermitRootLogin yes/' /etc/ssh/sshd_config; )

USER root
RUN (mkdir -p /root/.ssh/; \
     echo "StrictHostKeyChecking=no" > /root/.ssh/config; \
     echo "UserKnownHostsFile=/dev/null" >> /root/.ssh/config)

# -----------------------------------------------------------------
# Authorize SSH public keys (users "dev" and "root").
#
# The keypair is NOT stored in this repository. It lives in gitignored
# files under secrets/ and is injected at build time via BuildKit build
# secrets, so it never lands in image layers or the build cache:
#
#   DOCKER_BUILDKIT=1 docker build \
#     --secret id=ssh_pub_key,src=secrets/ssh_key.pub \
#     -t ubuntu-dev-jammy jammy/
#
#   secrets/ssh_key.pub  -> installed as authorized_keys in the image
#   secrets/ssh_key      -> matching PRIVATE key; stays on the client
#                           machine that connects via SSH (never used
#                           by the build)
# -----------------------------------------------------------------

# Install the authorized key for the "dev" user.
USER dev
RUN --mount=type=secret,id=ssh_pub_key \
    mkdir -p "${HOME}/.ssh" && chmod 0700 "${HOME}/.ssh" && \
    cp /run/secrets/ssh_pub_key "${HOME}/.ssh/authorized_keys" && \
    chmod 0444 "${HOME}/.ssh/authorized_keys"

# Install the same authorized key for "root".
USER root
RUN --mount=type=secret,id=ssh_pub_key \
    mkdir -p /root/.ssh && chmod 0700 /root/.ssh && \
    cp /run/secrets/ssh_pub_key /root/.ssh/authorized_keys && \
    chmod 0444 /root/.ssh/authorized_keys

# -----------------------------------------------------------------
# Update CMAKE. Use "cmake --version" to check.
# The new version of "cmake" is installed under "/usr/local/bin".
# The original version will still be under "/usr/bin".
# -----------------------------------------------------------------

USER root
WORKDIR /tmp
RUN (wget https://github.com/Kitware/CMake/releases/download/v3.24.3/cmake-3.24.3.tar.gz)
RUN (tar zxvf cmake-3.24.3.tar.gz)
WORKDIR /tmp/cmake-3.24.3
RUN (./bootstrap && gmake && make install)
WORKDIR /tmp
RUN (rm -rf /tmp/cmake-3.24.3 cmake-3.24.3.tar.gz)

# -----------------------------------------------------------------
# Add packages here so we can add more without the need to
# recompile CMAKE.
# -----------------------------------------------------------------

USER root
RUN apt-get update
RUN (apt-get install -y zip \
                        unzip \
                        locate \
                        jq \
                        tree \
                        vim \
                        curl \
                        iputils-ping \
                        netcat \
                        net-tools)
# Specific tools
RUN (apt clean)

# -----------------------------------------------------------------
# Install RUST compilation toolchain.
# -----------------------------------------------------------------

USER dev
RUN (curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y)
ENV PATH="${PATH}:/home/dev/.cargo/bin"
RUN (rustup update)


# -----------------------------------------------------------------
# Install JANSSON (for personal use)
# -----------------------------------------------------------------

USER dev
RUN (mkdir -p ${HOME}/componants/jansson-2.13)
WORKDIR /tmp
RUN (wget http://digip.org/jansson/releases/jansson-2.13.tar.gz)
RUN (tar xzvf jansson-2.13.tar.gz)
RUN (rm jansson-2.13.tar.gz)
WORKDIR /tmp/jansson-2.13
RUN (./configure --prefix=${HOME}/componants/jansson-2.13 --exec-prefix=${HOME}/componants/jansson-2.13)
RUN (make && make install)
WORKDIR /tmp
RUN (rm -rf jansson-2.13)

# -----------------------------------------------------------------
# Install the version 7.88 of libcurl (for personal use)
# -----------------------------------------------------------------

USER dev
RUN (mkdir -p ${HOME}/componants/curl-7.88.0)
WORKDIR /tmp
RUN (wget https://curl.se/download/curl-7.88.0.tar.gz)
RUN (tar xzvf curl-7.88.0.tar.gz)
RUN (rm curl-7.88.0.tar.gz)
WORKDIR /tmp/curl-7.88.0
RUN (./configure  --with-openssl --prefix=${HOME}/componants/curl-7.88.0 --exec-prefix=${HOME}/componants/curl-7.88.0)
RUN (make && make install)
WORKDIR /tmp
RUN (rm -rf curl-7.88.0)

# -----------------------------------------------------------------
# Install PCRE2 (for personal use)
# -----------------------------------------------------------------

USER dev
RUN (mkdir -p ${HOME}/componants/pcre2-10.42)
WORKDIR /tmp
RUN (wget https://github.com/PCRE2Project/pcre2/releases/download/pcre2-10.42/pcre2-10.42.tar.gz)
RUN (tar xzvf pcre2-10.42.tar.gz)
RUN (rm pcre2-10.42.tar.gz)
WORKDIR /tmp/pcre2-10.42
RUN (./configure --prefix=${HOME}/componants/pcre2-10.42 --exec-prefix=${HOME}/componants/pcre2-10.42)
RUN (make && make install)
WORKDIR /tmp
RUN (rm -rf pcre2-10.42)

# -----------------------------------------------------------------
# Install Chilkat (for personal use)
# -----------------------------------------------------------------

USER dev
WORKDIR /home/dev/componants
RUN (wget https://chilkatdownload.com/9.5.0.93/chilkat-9.5.0-x86_64-linux-gcc.tar.gz)
RUN (tar zxvf chilkat-9.5.0-x86_64-linux-gcc.tar.gz)
RUN (rm chilkat-9.5.0-x86_64-linux-gcc.tar.gz)

# -----------------------------------------------------------------
# Install Valgrind
# -----------------------------------------------------------------

USER root
WORKDIR /tmp
RUN (wget https://sourceware.org/pub/valgrind/valgrind-3.20.0.tar.bz2)
RUN (bzip2 -d valgrind-3.20.0.tar.bz2)
RUN (tar -xvf valgrind-3.20.0.tar)
RUN (rm valgrind-3.20.0.tar)
WORKDIR /tmp/valgrind-3.20.0
RUN (./configure)
RUN (make && make install)
WORKDIR /tmp
RUN (rm -rf /tmp/valgrind-3.20.0)

# -----------------------------------------------------------------
# Install various Perl modules
# -----------------------------------------------------------------

USER root
RUN (export PERL_MM_USE_DEFAULT=1 && yes | cpan -i JSON)

# -----------------------------------------------------------------
# Install GOLANG
# See: https://go.dev/doc/install
# -----------------------------------------------------------------

USER root
WORKDIR /tmp
RUN (wget https://go.dev/dl/go1.20.2.linux-amd64.tar.gz)
RUN (rm -rf /usr/local/go && tar -C /usr/local -xzf go1.20.2.linux-amd64.tar.gz)
RUN (rm go1.20.2.linux-amd64.tar.gz)
RUN (echo "PATH=${PATH}:/usr/local/go/bin" > ${HOME}/.profile)
USER dev
RUN (echo "PATH=${PATH}:/usr/local/go/bin" > ${HOME}/.profile)

# -----------------------------------------------------------------
# Configure the system for SSH
# Look at the SSHD startup script "/etc/init.d/ssh".
# This script prepares the environment for the SSH daemon to start.
# -----------------------------------------------------------------

USER root
RUN (mkdir /run/sshd)
RUN (chmod 0755 /run/sshd)

# -----------------------------------------------------------------
# Configure the boot
# -----------------------------------------------------------------

USER root
COPY entrypoint.sh /entrypoint.sh
RUN (chmod +x /entrypoint.sh)
RUN (dos2unix /entrypoint.sh)

# -----------------------------------------------------------------
# Update tools and environments.
# -----------------------------------------------------------------

USER root
RUN (updatedb)

# -----------------------------------------------------------------
# Start the SSH daemon.
# -----------------------------------------------------------------

STOPSIGNAL SIGTERM
CMD ["/usr/sbin/sshd", "-D"]
ENTRYPOINT ["/entrypoint.sh"]

