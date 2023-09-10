#!/bin/bash

. ./config.env
echo "Disk Size: $DISK_SIZE"
echo "Download url: $ALPINE_ISO_URL"
echo "Alpine file: $ALPINE_ISO_FILE"
echo "Alpine path: $ALPINE_PATH"

echo "Install dependencies"
pkg install -y qemu-system-x86-64-headless \
               qemu-utils \
               wget \
               expect


echo "Get Alpine Linux"

rm -r $ALPINE_PATH

[-d $ALPINE_PATH] || mkdir -p $ALPINE_PATH
# https://alpinelinux.org/downloads/

[-d ~/alpine/$ALPINE_ISO_FILE] || wget -P ~/alpine $ALPINE_ISO_URL

echo "Downloaded File: $(ls $ALPINE_PATH | grep $ALPINE_ISO_FILE)"

# expect -f setup-qemu.expect.sh
