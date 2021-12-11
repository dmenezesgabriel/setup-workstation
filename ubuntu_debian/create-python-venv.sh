#!/bin/sh
# --------------------------------------------------------------------------- #
# Create python general virtual environment
# --------------------------------------------------------------------------- #
sudo apt-get install -y python3-venv

echo "Creating 'general' virtual environment"

# Install python virtual environment
python3 -m venv ~/environments/general


echo "Installing default python libs"
sudo apt-get -qq install -y python3-pip

~/environments/general/bin/pip install black isort flake8 pytest wheel

echo "Adding custom configs to ~/.zshrc"
# --------------------------------------------------------------------------- #
# Custom configuration at zshrc
# --------------------------------------------------------------------------- #
cat <<'EOF' >> ~/.bashrc
## Custom ##
# Activate Python general virtual environment
alias generalenv="source ~/environments/general/bin/python3"
# Always require python environment
export PIP_REQUIRE_VIRTUALENV=true
# Don't write __pycache__, *.pyc and similar files
export PYTHONDONTWRITEBYTECODE=1
# Activate venv automagically
generalenv
EOF
# --------------------------------------------------------------------------- #
# Reload shell config
# --------------------------------------------------------------------------- #
. ~/.bashrc