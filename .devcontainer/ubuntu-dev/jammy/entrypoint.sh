#!/bin/bash
set -e

# Start daemon here.

# The command below will execute whatever command is given as parameters to this script.
# Please note that we could have executed the following command: `/usr/sbin/sshd -D`,
# instead of `exec "$@"`.

exec "$@"
