#!/bin/bash
# Pre-commit hook: ensure Ansible vault files are encrypted
for f in "$@"; do
  if ! head -1 "$f" | grep -q '^\$ANSIBLE_VAULT'; then
    echo "ERROR: $f is not encrypted!"
    exit 1
  fi
done
