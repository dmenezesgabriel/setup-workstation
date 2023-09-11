#!/bin/bash

# Change Windows-style line endings to (CRLF) to Unix-style (LF) at the bottom of vscode.

export ALPINE_PATH=~/alpine
export SSH_PATH=~/.ssh
export DISK_SIZE=4G
export ROOT_PASSWORD=secret123
export ALPINE_ISO_FILE=alpine-virt-3.18.3-x86_64.iso
export ALPINE_ISO_URL=https://dl-cdn.alpinelinux.org/alpine/v3.18/releases/x86_64/$ALPINE_ISO_FILE

echo -e "=========== Environment ===========\n"

echo "Disk Size: $DISK_SIZE"
echo "Download url: $ALPINE_ISO_URL"
echo "Alpine file: $ALPINE_ISO_FILE"
echo "Alpine path: $ALPINE_PATH"

echo -e "=========== Install dependencies ===========\n"

apt update -q
apt install -yq qemu-system-x86-64-headless \
               openssh \
               qemu-utils \
               wget \
               expect


echo -e "=========== Download Alpine ===========\n"

rm -r $ALPINE_PATH

mkdir -p $ALPINE_PATH
# https://alpinelinux.org/downloads/

wget -P $ALPINE_PATH $ALPINE_ISO_URL

echo "Downloaded File: $(ls $ALPINE_PATH | grep $ALPINE_ISO_FILE)"

rm -r $SSH_PATH

mkdir -p $SSH_PATH

echo -e "=========== Run expect file ===========\n"

expect -f qemu.expect

echo -e "=========== Create alpine.sh ===========\n"

echo "qemu-system-x86_64 -m 512 -netdev user,id=n1,hostfwd=tcp::2222-:22 -device virtio-net,netdev=n1 -nographic $ALPINE_PATH/alpine.qcow2" >> $ALPINE_PATH/alpine.sh"