#!/bin/bash

start_time=$(date +%s)

echo "=========== Install packages ===========\n"

apt update -q
apt install -y root-repo \
               x11-repo \

apt install -y wget \
               git

end_time=$(date +%s)

elapsed_time=$((end_time - start_time))

echo "Elapsed time: $elapsed_time seconds"