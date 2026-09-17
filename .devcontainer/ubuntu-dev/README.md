# Ubuntu docker containers for developers

This repository contains the "Dockerfile" that build a development environment for C/C++/Rust developers with Ubuntu [Jammy](jammy/Dockerfile) and [Noble](noble/Dockerfile) docker containers.

> This image is designed to be used with CLION full remote mode (through SSH).
>
> You can easily add other development environments (for Python, Perl, NodeJs, Java...).

## Build the image

```bash
cd jammy
docker build --tag ubuntu-dev-jammy --progress=plain .
```

or:

```bash
cd noble
docker build --tag ubuntu-dev-noble --progress=plain .
```

> Useful command: `docker system prune -a` (this will clean the cache).
>
> The option `--progress=plain` is useful for debugging (not mandatory).

## Run a container

### Ubuntu Jammy

**Bash**

```bash
CONTAINER_NAME="ubuntu-dev-jammy"
docker run --cap-add=SYS_PTRACE \
           --security-opt seccomp=unconfined \
           --detach \
           --net=bridge \
           --interactive \
           --tty \
           --rm \
           --publish 2222:22/tcp \
           --volume="$(pwd):/home/dev" \
           "${CONTAINER_NAME}"
```

* `--publish 2222:22/tcp`: for SSH connections.

> **One liner**:
> 
> ```bash
> docker run --cap-add=SYS_PTRACE --security-opt seccomp=unconfined --detach --net=bridge --interactive --tty --rm --publish 2222:22/tcp --volume="$(pwd):/home/dev" ubuntu-dev-jammy
> ```


**MSDOS**

```
SET CONTAINER_NAME="ubuntu-dev-jammy"
docker run --cap-add=SYS_PTRACE ^
           --security-opt seccomp=unconfined ^
           --detach ^
           --net=bridge ^
           --interactive ^
           --tty ^
           --rm ^
           --publish 2222:22/tcp ^
           --publish 5000:5000/tcp ^
           --volume="%cd%:/home/dev" ^
           %CONTAINER_NAME%
```

* `--publish 2222:22/tcp`: for SSH connections.

> **One liner**:
>
> ```
> docker run --cap-add=SYS_PTRACE --security-opt seccomp=unconfined --detach --net=bridge --interactive --tty --rm --publish 2222:22/tcp --publish 5000:5000/tcp --volume="%cd%:/home/dev" ubuntu-dev-jammy
> ```

### Ubuntu Noble

**Bash**

```bash
CONTAINER_NAME="ubuntu-dev-noble"
docker run --cap-add=SYS_PTRACE \
           --security-opt seccomp=unconfined \
           --detach \
           --net=bridge \
           --interactive \
           --tty \
           --rm \
           --publish 2222:22/tcp \
           --publish 5000:5000/tcp \
           --volume="$(pwd):/home/dev" \
           "${CONTAINER_NAME}"
```

* `--publish 2222:22/tcp`: for SSH connections.
* `--publish 5000:5000/tcp`: for GDBGUI.

> **One liner**:
> 
> ```bash
> docker run --cap-add=SYS_PTRACE --security-opt seccomp=unconfined --detach --net=bridge --interactive --tty --rm --publish 2222:22/tcp --volume="$(pwd):/home/dev" ubuntu-dev-noble
> ```


**MSDOS**

```
SET CONTAINER_NAME="ubuntu-dev-noble"
docker run --cap-add=SYS_PTRACE ^
           --security-opt seccomp=unconfined ^
           --detach ^
           --net=bridge ^
           --interactive ^
           --tty ^
           --rm ^
           --publish 2222:22/tcp ^
           --publish 5000:5000/tcp ^
           --volume="%cd%:/home/dev" ^
           %CONTAINER_NAME%
```

* `--publish 2222:22/tcp`: for SSH connections.
* `--publish 5000:5000/tcp`: for GDBGUI.

> **One liner**:
>
> ```
> docker run --cap-add=SYS_PTRACE --security-opt seccomp=unconfined --detach --net=bridge --interactive --tty --rm --publish 2222:22/tcp --publish 5000:5000/tcp --volume="%cd%:/home/dev" ubuntu-dev-noble
> ```

### Notes

The options `--cap-add=SYS_PTRACE` and `--security-opt seccomp=unconfined` allow you to use GDB.

See:
* [https://docs.docker.com/engine/containers/run/#runtime-privilege-and-linux-capabilities](Runtime privilege and Linux capabilities).
* [http://manpagesfr.free.fr/man/man2/ptrace.2.html](ptrace man page).

## Connecting to the container using SSH

The OS is configured with 2 UNIX users:

| **User**           | **Password**       | **MobaXterm session**                     | **SSH connections using the private SSH key**                                                                                             | **SSH connection using password**                                                                        |
|--------------------|--------------------|-------------------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------|----------------------------------------------------------------------------------------------------------|
| `root`             | `root`             | [root](data/ContainerUbuntuSamyRoot.moba) | `ssh -o StrictHostKeychecking=no -o UserKnownHostsFile=NUL -o IdentitiesOnly=yes -o IdentityFile=data/private.key -p 2222 root@localhost` | `ssh -o UserKnownHostsFile=NUL -o StrictHostKeychecking=no -o IdentitiesOnly=yes -p 2222 root@localhost` |
| `dev`              | `dev`              | [dev](data/ContainerUbuntuSamyDev.moba)   | `ssh -o StrictHostKeychecking=no -o UserKnownHostsFile=NUL -o IdentitiesOnly=yes -o IdentityFile=data/private.key -p 2222 dev@localhost`  | `ssh -o UserKnownHostsFile=NUL -o StrictHostKeychecking=no -o IdentitiesOnly=yes -p 2222 dev@localhost`  |

> `dev` is "_sudoer_".

> Make sure that the private key file has the right permission (`chmod 600 data/private.key`).
>
> You may need to clean the host SSH configuration:
>
> `ssh-keygen -f "%USERPROFILE%\.ssh\known_hosts" -R "[localhost]:2222"`.

## SCP 

From the host, download a file (stored on the container):

```bash
scp -o StrictHostKeychecking=no -o UserKnownHostsFile=NUL -o IdentitiesOnly=yes -o IdentityFile=data/private.key -P 2222 dev@localhost:/tmp/file-to-download ./
```

From the host, upload a file (stored on the host):

```bash
scp -o StrictHostKeychecking=no -o UserKnownHostsFile=NUL -o IdentitiesOnly=yes -o IdentityFile=data/private.key -P 2222 file-to-upload dev@localhost:/tmp/
```

## Using GDBGUI (Ubuntu Noble only)

Connect to the container ([Ubuntu Noble](noble) **ONLY**) as user `dev`, then run the following commands:

```
cd app
make
gdbgui --host 0.0.0.0 --port 5000 ./app &
```

Open the following URL from your browser: [http://127.0.0.1:5000/dashboard](http://127.0.0.1:5000/dashboard)

> **WARNING**: the URL starts with "**127.0.0.1**" (**and nothing else**) !!!

# Notes for Windows

## Docker

Path to the CLI executable: `C:\Program Files\Docker\Docker`

> Must be added to the environment variable.

```
C:> where docker
C:\Program Files\Docker\Docker\resources\bin\docker
C:\Program Files\Docker\Docker\resources\bin\docker.exe
```

Before you can build the image, or run a container, you must start the Docker Deamon. This is done through the GUI.

## Docker Desktop - Unexpected WSL error

See: [this document](https://github.com/microsoft/WSL/issues/11273)

```
C:>wsl --status
Le service ne peut pas être démarré parce qu’il est désactivé ou qu’aucun périphérique activé ne lui est associé.
Code d’erreur : Wsl/0x80070422
```

Start `CMD.EXE` as adminitrator, and then:

```
C:>sc.exe config wslservice start= demand
```

> For your information, I found that the problem arose after my antivirus (AVAST) performed a system cleanup.

# Resources

* [StackOverflow](https://stackoverflow.com/questions/75675823/docker-build-script-to-execute-does-not-exist-but-it-actually-exists-works): a workaround for a strange problem on Windows only.
* [StackOverflow](https://stackoverflow.com/questions/54397706/how-to-output-a-multiline-string-in-dockerfile-with-a-single-command): multiline string in a `Dockerfile`.
