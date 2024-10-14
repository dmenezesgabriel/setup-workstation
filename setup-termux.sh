#!/bin/bash

start_time=$(date +%s)

echo "=========== Install dependencies =================\n"

pkg update && pkg upgrade -y
pkg install -y \
    x11-repo \
    proot \
    proot-distro \
    tur-repo \
    pulseaudio \
    openssh \
    git \
    curl \
    wget \
    zsh \
    vim \
    python \
    python-pip \
    nodejs-lts

echo "=========== Create virtual environment ===========\n"

rm -rf ~/environments/general && \
python -m venv --system-site-packages ~/environments/general && \
echo "source ~/environments/general/bin/activate" >> ~/.bashrc && \
source ~/environments/general/bin/activate

echo "=========== Finish ===============================\n"

end_time=$(date +%s)

elapsed_time=$((end_time - start_time))

echo "Elapsed time: $elapsed_time seconds"
