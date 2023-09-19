#!/bin/bash

start_time=$(date +%s)


echo "\n=========== Packages ===========\n"

pkg update
pkg upgrade -y

pkg install -y tur-repo
pkg install -y code-server

echo "\n=========== Extensions ===========\n"

code-server --install-extension ms-python.python

end_time=$(date +%s)

elapsed_time=$((end_time - start_time))

echo "Elapsed time: $elapsed_time seconds"
