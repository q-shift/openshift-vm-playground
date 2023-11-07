#!/bin/bash

systemctl --user enable --now podman.socket
sudo loginctl enable-linger 1000

socat TCP-LISTEN:2376,reuseaddr,fork,bind=0.0.0.0 UNIX-SOCKET:/var/run/user/1000/podman/podman.sock &