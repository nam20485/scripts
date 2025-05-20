#! /bin/bash

# Docker warning message (global variable)
DOCKER_WARNING="[WARNING] This script is not recommended for production systems as it gives the user root access to the docker daemon!
(https://docs.docker.com/engine/security/#docker-daemon-attack-surface)
Consider running Docker in rootless mode instead for production systems.
(https://docs.docker.com/engine/security/rootless/)"

# Check for environment variables named PROD or PRODUCTION (case-insensitive)
if env | grep -qiE '^PROD(=|$)|^PRODUCTION(=|$)'; then
    echo -e "$DOCKER_WARNING"
    echo -e "\nExiting..."
    exit 1
fi

echo "Uninstalling any existing docker packages..."
# uninstall any existing docker packages
for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do
    sudo apt-get remove $pkg;
done

# install docker engine
echo "Installing docker engine..."
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh

# add current user and docker user to docker group to allow running docker commands without sudo
# NOTE: See warning below for production systems
if ! getent group docker > /dev/null; then
    echo "Creating docker group..."
    groupadd docker
fi

# if ! id -nG "$USER" | grep -qw docker; then
#     echo "Adding user $USER to docker group..."
#     usermod -aG docker $USER
# fi
echo "Adding user $USER to docker group..."
usermod -aG docker $USER
#newgrp docker

# verify docker installation runs WITHOUT sudo/root
docker run hello-world

# install coder
curl -fsSL https://coder.com/install.sh -o coder-install.sh
chmod +x ./coder-install.sh
./coder-install.sh --mainline --method detect --net-admin

# check installation
coder --version

## Start Coder now and on reboot
# $ sudo systemctl enable --now coder
# $ journalctl -u coder.service -b

# # Or just run the server directly
# $ coder server

# Configuring Coder: https://coder.com/docs/admin/setup

# To connect to a Coder deployment:

# $ coder login <deployment url>
