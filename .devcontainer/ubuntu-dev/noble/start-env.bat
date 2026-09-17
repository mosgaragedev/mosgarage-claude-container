@echo off
setlocal enabledelayedexpansion
REM Build the test en
REM
REM This script performs the following actions:
REM 1. It creates a network (192.168.1.0/24).
REM 2. It launches three containers within the previously created network, each with a predefined IP address.
REM 3. It configures the environments of each container (by customizing the BASH prompt).
REM 4. It copies files from the host to the containers.


SET PWD=%~dp0
SET PWD=%PWD:~0,-1%

REM ============= Configuration::START =============

SET CONTAINER="ubuntu-dev-noble"
SET SSH_KEY="%PWD%\..\data\private.key"

SET NAME0="proxy"
SET IP0=192.168.1.20
SET PORT0=2230

SET NAME1="source"
SET IP1=192.168.1.21
SET PORT1=2231

SET NAME2="destination"
SET IP2=192.168.1.22
SET PORT2=2232

SET "SUBNET=192.168.1.0/24"
SET "NETWORK_NAME=test_network"

REM ============= Configuration::STOP =============

echo "Create the subnet"
set found=0
for /f "delims=" %%I in ('docker network ls -q') do (
    docker network inspect %%I --format "{{.Name}} {{range .IPAM.Config}}{{.Subnet}}{{end}}" 2>nul | findstr /C:"%SUBNET%"
    docker network inspect %%I --format "{{.Name}} {{range .IPAM.Config}}{{.Subnet}}{{end}}" 2>nul | findstr /C:"%SUBNET%" >nul
    if %ERRORLEVEL%==0 (
        set found=1
        goto :break_loop
    )
)
:break_loop

if %found%==1 (
    echo The subnet %SUBNET% already exists.
) else (
    echo Create the subnet %SUBNET%
    docker network create --subnet=%SUBNET% %NETWORK_NAME%
)

echo "Start %NAME0%"
docker run --detach ^
           --net=test_network ^
           --ip %IP0% ^
           --interactive ^
           --tty ^
           --rm ^
           --publish %PORT0%:22/tcp ^
           --name %NAME0% ^
           %CONTAINER%

echo "Start %NAME1%"
docker run --detach ^
           --net=test_network ^
           --ip %IP1% ^
           --interactive ^
           --tty ^
           --rm ^
           --publish %PORT1%:22/tcp ^
           --name %NAME1% ^
           %CONTAINER%

echo "Start %NAME2%"
docker run --detach ^
           --net=test_network ^
           --ip %IP2% ^
           --interactive ^
           --tty ^
           --rm ^
           --publish %PORT2%:22/tcp ^
           --name %NAME2% ^
           %CONTAINER%

REM Print the list of running containers.
docker container ls --all

REM Configure the containers.
ssh -o StrictHostKeychecking=no -o UserKnownHostsFile=NUL -o IdentitiesOnly=yes -o IdentityFile=%SSH_KEY% -p %PORT0% root@localhost "printf \"\n%IP0%  %NAME0%\n%IP1%  %NAME1%\n%IP2%  %NAME2%\n\" >> /etc/hosts"
ssh -o StrictHostKeychecking=no -o UserKnownHostsFile=NUL -o IdentitiesOnly=yes -o IdentityFile=%SSH_KEY% -p %PORT1% root@localhost "printf \"\n%IP0%  %NAME0%\n%IP1%  %NAME1%\n%IP2%  %NAME2%\n\" >> /etc/hosts"
ssh -o StrictHostKeychecking=no -o UserKnownHostsFile=NUL -o IdentitiesOnly=yes -o IdentityFile=%SSH_KEY% -p %PORT2% root@localhost "printf \"\n%IP0%  %NAME0%\n%IP1%  %NAME1%\n%IP2%  %NAME2%\n\" >> /etc/hosts"

ssh -o StrictHostKeychecking=no -o UserKnownHostsFile=NUL -o IdentitiesOnly=yes -o IdentityFile=%SSH_KEY% -p %PORT0% root@localhost "printf \"PS1=\\\"%NAME0% >\\\"\" >> /home/dev/.bashrc"
ssh -o StrictHostKeychecking=no -o UserKnownHostsFile=NUL -o IdentitiesOnly=yes -o IdentityFile=%SSH_KEY% -p %PORT1% root@localhost "printf \"PS1=\\\"%NAME1% >\\\"\" >> /home/dev/.bashrc"
ssh -o StrictHostKeychecking=no -o UserKnownHostsFile=NUL -o IdentitiesOnly=yes -o IdentityFile=%SSH_KEY% -p %PORT2% root@localhost "printf \"PS1=\\\"%NAME2% >\\\"\" >> /home/dev/.bashrc"

REM Open connections to the containers.
start "%NAME0%" cmd /c ssh -o StrictHostKeychecking=no -o UserKnownHostsFile=NUL -o IdentitiesOnly=yes -o IdentityFile=%SSH_KEY% -p %PORT0% dev@localhost
start "%NAME1%" cmd /c ssh -o StrictHostKeychecking=no -o UserKnownHostsFile=NUL -o IdentitiesOnly=yes -o IdentityFile=%SSH_KEY% -p %PORT1% dev@localhost
start "%NAME2%" cmd /c ssh -o StrictHostKeychecking=no -o UserKnownHostsFile=NUL -o IdentitiesOnly=yes -o IdentityFile=%SSH_KEY% -p %PORT2% dev@localhost

REM Transfer files
scp -o StrictHostKeychecking=no -o UserKnownHostsFile=NUL -o IdentitiesOnly=yes -o IdentityFile=%SSH_KEY% -P %PORT0% %SSH_KEY% dev@localhost:/home/dev/.ssh/private.key
ssh -o StrictHostKeychecking=no -o UserKnownHostsFile=NUL -o IdentitiesOnly=yes -o IdentityFile=%SSH_KEY% -p %PORT0% dev@localhost "chmod 0400 /home/dev/.ssh/private.key"

