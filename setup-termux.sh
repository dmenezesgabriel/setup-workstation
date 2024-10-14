#!/bin/bash

start_time=$(date +%s)

echo "=========== Install dependencies =================\n"

pkg update && pkg upgrade -y
pkg install -y \
    openssh \
    git \
    curl \
    wget \
    zsh \
    vim \
    python \
    python-pip

echo "=========== Create virtual environment ===========\n"

rm -rf ~/environments/general && \
python -m venv --system-site-packages ~/environments/general && \
echo "source ~/environments/general/bin/activate" >> ~/.bashrc && \
source ~/environments/general/bin/activate

echo "=========== Finish ===============================\n"

end_time=$(date +%s)

elapsed_time=$((end_time - start_time))

echo "Elapsed time: $elapsed_time seconds"
