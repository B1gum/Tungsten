#!/usr/bin/env bash
set -euo pipefail

TARGET_DIR="${HOME}/.local/share/nvim/lazy/plenary.nvim"

if [ -d "${TARGET_DIR}" ]; then
  echo "✔ plenary.nvim already installed at ${TARGET_DIR}"
  exit 0
fi

mkdir -p "$(dirname "${TARGET_DIR}")"

echo "Cloning plenary.nvim into ${TARGET_DIR}..."

git clone --depth 1 https://github.com/nvim-lua/plenary.nvim "${TARGET_DIR}"

echo "✔ plenary.nvim installed"

