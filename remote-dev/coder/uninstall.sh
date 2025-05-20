#! /bin/sh

# remove application
sudo apt remove coder -y

# remove any manual installations of coder
sudo rm /usr/local/bin/coder

# remove systemd service
sudo rm /etc/coder.d

# remove any cache and config files

rm -rf ~/.config/coderv2
rm -rf ~/.cache/coder
