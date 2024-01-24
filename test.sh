#!/bin/bash

# Getting the root partition
p_root=$(awk '/\s\/\s/ {print prev} {prev = $0}' /etc/fstab | sed 's/^#\s*//')

# Adding the root partition to the snapper-rollback config file
sudo sed -i '/^#dev/d' /etc/snapper-rollback.conf
echo "dev = $p_root" | sudo tee -a /etc/snapper-rollback.conf
