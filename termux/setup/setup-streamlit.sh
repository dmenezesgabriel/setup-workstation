#!/bin/bash

STREAMLIT_APP_PATH=~/streamlit_app

echo -e "=========== Environment ===========\n"

echo "Streamlit app path: $STREAMLIT_APP_PATH"

echo -e "=========== Install dependencies ===========\n"

apt update
apt install -y tur-repo

apt update && apt upgrade -y
apt install --fix-policy -y build-essential \
               libandroid-execinfo \
               libarrow-cpp \
               make \
               clang \
               ninja \
               binutils \
               python \
               python-pip \

echo "Python version: $(python --version)"

echo -e "=========== Create streamlit app ===========\n"

rm -r $STREAMLIT_APP_PATH
mkdir -p $STREAMLIT_APP_PATH
``
cd $STREAMLIT_APP_PATH

echo -e "=========== Install streamlit ===========\n"

rm -r venv
python -m venv venv


export MATHLIB="m"

export LDFLAGS="-lpython3.11"

export CFLAGS=-Wno-implicit-function-declaration

venv/bin/python -m pip install --no-cache-dir numpy

echo "$(venv/bin/python -m pip freeze)"

echo "$( python -c 'import numpy; print(numpy.__version__)')"

# export CFLAGS="-Wno-deprecated-declarations -Wno-unreachable-code"

# venv/bin/python -m pip install --no-cache-dir pandas==1.44.0

# echo "$( python -c 'import pandas; print(pandas.__version__)')"

# venv/bin/python -m pip install --no-cache-dir streamlit==1.11.1

# echo -e "=========== Run streamlit ===========\n"

# venv/bin/python -m streamlit hello
