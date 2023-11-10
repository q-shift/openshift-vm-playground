#!/bin/bash

sudo dnf -y install podman socat
systemctl --user enable --now podman.socket
loginctl enable-linger 1000

sudo modprobe iptable-nat

socat TCP-LISTEN:2376,reuseaddr,fork,bind=0.0.0.0 unix:/run/user/1000/podman/podman.sock &