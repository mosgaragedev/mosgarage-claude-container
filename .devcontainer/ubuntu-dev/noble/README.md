The script [start-env.bat](start-env.bat) performs the following actions:

1. It creates a subnet (if necessary).
2. It launches three containers within the previously created subnet, each with a predefined IP address.
3. It configures the environments of each container (by customizing the BASH prompt).
4. It copies files from the host to the containers.
