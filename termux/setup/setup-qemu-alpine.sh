#!/bin/bash

# Change Windows-style line endings to (CRLF) to Unix-style (LF) at the bottom of vscode.
start_time=$(date +%s)

export ALPINE_PATH=~/alpine
export SSH_PATH=~/.ssh
export DISK_SIZE=10G
export ROOT_PASSWORD=secret123
export ALPINE_ISO_FILE=alpine-virt-3.14.0-x86_64.iso
export ALPINE_ISO_URL=https://dl-cdn.alpinelinux.org/alpine/v3.14/releases/x86_64/$ALPINE_ISO_FILE

echo "=========== Environment ===========\n"

echo "Disk Size: $DISK_SIZE"
echo "Download url: $ALPINE_ISO_URL"
echo "Alpine file: $ALPINE_ISO_FILE"
echo "Alpine path: $ALPINE_PATH"

echo "=========== Install dependencies ===========\n"

apt update -q
apt install -yq qemu-system-x86-64-headless \
               openssh \
               qemu-utils \
               wget \
               expect


echo "=========== Download Alpine ===========\n"

rm -r $ALPINE_PATH

mkdir -p $ALPINE_PATH

cp -r alpine-setup.conf $ALPINE_PATH/alpine-setup.conf

echo "$(ls -alh $ALPINE_PATH)"

wget -P $ALPINE_PATH $ALPINE_ISO_URL

echo "Downloaded File: $(ls $ALPINE_PATH | grep $ALPINE_ISO_FILE)"

rm -r $SSH_PATH

mkdir -p $SSH_PATH

echo "=========== Run expect file ===========\n"

expect -f qemu.expect

echo "=========== Create alpine.sh ===========\n"

echo "qemu-system-x86_64 -m 1024 -netdev user,id=n1,hostfwd=tcp::2222-:22 -device virtio-net,netdev=n1 -nographic $ALPINE_PATH/alpine.qcow2" >> $ALPINE_PATH/alpine.sh

end_time=$(date +%s)

elapsed_time=$((end_time - start_time))

echo "Elapsed time: $elapsed_time seconds"
