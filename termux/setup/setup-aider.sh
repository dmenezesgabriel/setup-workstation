#!/bin/bash

# Exit on any error
set -e

# Update packages
pkg update -y && pkg upgrade -y

# Install required packages
pkg install -y git python clang cmake libffi openssl rust libgit2

# Upgrade pip and set up a virtual environment
pip install --upgrade pip setuptools wheel virtualenv
virtualenv aider-env
source aider-env/bin/activate

# Optional: Ensure Rust is usable
command -v rustc >/dev/null || echo "⚠️ Rust not found in PATH!"

# Install tree-sitter with relaxed CFLAGS
CFLAGS="-Wno-error=implicit-function-declaration" pip install --prefer-binary tree-sitter

# Set LIBGIT2_DIR for pygit2
export LIBGIT2_DIR=/data/data/com.termux/files/usr
pip install pygit2

# Now install Aider itself
pip install aider-chat

# Test if aider installed correctly
echo "✅ Aider installed. Running 'aider --help':"
aider --help || echo "❌ Aider failed to run"
