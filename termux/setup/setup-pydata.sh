#!/bin/bash

PYDATA_PATH=~/pydata

echo "=========== Environment ===========\n"

echo "Streamlit app path: $PYDATA_PATH"

echo "=========== Install dependencies ===========\n"

apt update
apt install -y tur-repo

apt update && apt upgrade -y
apt install --fix-policy -y build-essential \
               libandroid-execinfo \
               libarrow-cpp \
               make \
               clang \
               ninja \
               rust \
               libffi \
               binutils \
               libzmq \
               python \
               python-pip \
               python-numpy \
               python-pandas \

echo "\nPython version: $(python --version)"
echo "\nPython global libs: \n$(python -m pip freeze)"

echo -e "=========== Create streamlit app ===========\n"

rm -r $PYDATA_PATH
mkdir -p $PYDATA_PATH
``
cd $PYDATA_PATH

echo -e "=========== Install Python Packages ===========\n"

rm -r venv
python -m venv --system-site-packages venv

export MATHLIB="m"

export LDFLAGS="-lpython3.11"

export CFLAGS="-w"

# venv/bin/python -m pip install --no-cache-dir numpy==1.19.3
# venv/bin/python -m pip install --no-cache-dir pandas==1.3.0
# venv/bin/python -m pip install --no-cache-dir pillow==7.1.0


echo "$(venv/bin/python -c 'import numpy; print(numpy.__version__)')"

echo "$(venv/bin/python -c 'import pandas; print(pandas.__version__)')"

venv/bin/python -m pip install --upgrade pip setuptools wheel
venv/bin/python -m pip install --upgrade jupyterlab jupyterlab-git

venv/bin/python -m pip install streamlit
