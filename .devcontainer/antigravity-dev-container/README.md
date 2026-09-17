## 1. Prerequisites

![](https://velog.velcdn.com/images/agnusdei1207/post/8013ef11-59d7-4d19-a343-af980f2ec10a/image.png)

- **remote-ssh extension**: Installation of an SSH-related extension is required -> It is recommended to install the extension with the highest number of downloads.
- **SSH Client**: An **SSH Client** (built-in on Windows 10/11) or an SSH plugin for your IDE is required.

## 2. How to Run (CLI)

Navigate to the directory containing the `compose.yml` file in your terminal (PowerShell or cmd) and run the following command:

```bash
docker compose up -d --build
```

## 3. IDE Connection Method (SSH)

Use the **Remote - SSH** feature or plugin in your current IDE (such as VS Code) to connect using the information below.
Please change the password to a secure one. Refer to the Dockerfile comments.

- **Host**: `localhost`
- **Port**: `2222`
- **User**: `root`
- **Password**: `password`

### Connection Command Example

```bash
ssh root@localhost -p 2222

```

## 4. Docker Internal Features

- **Docker-in-Docker**: You can use `docker` commands inside the container to build images or manage containers.
- **Volume Mount**: The `/app` directory is synchronized with the host's project folder.

## 5. How to Stop

```bash
docker compose down

```

## Precautions

Since the Docker container itself runs as root (rootful), it is not perfectly secure. If you are concerned, please create and run a Podman container instead.
Additionally, please note that there may be security issues inherent to the remote extension program itself.
