#!/bin/bash
set -e

# Install Ansible Galaxy roles
ansible-galaxy install -r .devcontainer/ansible-galaxy-requirements.yaml

# Install pre-commit and detect-secrets
echo "Installing pre-commit and detect-secrets..."
pip install --user pre-commit detect-secrets

# Install pre-commit hooks
if [ -f .pre-commit-config.yaml ]; then
  echo "Installing git hooks..."
  pre-commit install
  echo "Pre-commit hooks installed successfully"
else
  echo "Warning: .pre-commit-config.yaml not found, skipping hook installation"
fi
