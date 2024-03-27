#!/bin/bash

start_time=$(date +%s)

VENV_PARENT_DIR=$1

if [ $# -eq 0 ]; then
  echo "No arguments provided. Script will exit with an error."
  exit 1
fi

echo "=========== Environment ===========\n"

echo "Streamlit app path: $VENV_PARENT_DIR"

echo "=========== Install dependencies ===========\n"

mkdir -p $VENV_PARENT_DIR

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
               libjpeg-turbo \
               python \
               python-pip \
               python-numpy \
               python-pandas \
               python-pyarrow \
               python-scipy \

echo "\nPython version: $(python --version)"
echo "\nPython global libs: \n$(python -m pip freeze)"

echo "=========== Create pydata directory ===========\n"

rm -r $VENV_PARENT_DIR
mkdir -p $VENV_PARENT_DIR

cp requirements.txt $VENV_PARENT_DIR

cd $VENV_PARENT_DIR

echo "=========== Create virtual environment ===========\n"

python -m venv --system-site-packages venv

export MATHLIB="m"

export LDFLAGS=" -lpython3.11 -lm"

echo "$(venv/bin/python -c 'import numpy; print(numpy.__version__)')"

echo "$(venv/bin/python -c 'import pandas; print(pandas.__version__)')"

echo "$(venv/bin/python -c 'import pyarrow; print(pyarrow.__version__)')"

echo "=========== Update setup tools and wheel ===========\n"

venv/bin/python -m pip install --upgrade pip setuptools wheel

echo "=========== Install jupyterlab ===========\n"

venv/bin/python -m pip install --upgrade jupyterlab jupyterlab-git

echo "=========== Install Streamlit ===========\n"

venv/bin/python -m pip install typing-extensions
venv/bin/python -m pip install altair==5.1.1
venv/bin/python -m pip install blinker==1.6.2
venv/bin/python -m pip install cachetools==5.3.1
venv/bin/python -m pip install click==8.1.7
venv/bin/python -m pip install gitpython==3.1.36
venv/bin/python -m pip install importlib-metadata
venv/bin/python -m pip install pillow==10.0.0
venv/bin/python -m pip install protobuf==4.23.3
venv/bin/python -m pip install toml==0.10.2
venv/bin/python -m pip install pydeck==0.8.0
venv/bin/python -m pip install pympler==1.0.1
venv/bin/python -m pip install requests==2.31.0
venv/bin/python -m pip install rich==13.5.2
venv/bin/python -m pip install tenacity==8.2.3
venv/bin/python -m pip install tornado==6.3.3
venv/bin/python -m pip install tzlocal==5.0.1
venv/bin/python -m pip install validators==0.22.0
venv/bin/python -m pip install watchdog==3.0.0

venv/bin/python -m pip install --no-cache-dir --no-dependencies streamlit

end_time=$(date +%s)

elapsed_time=$((end_time - start_time))

echo "Elapsed time: $elapsed_time seconds"
