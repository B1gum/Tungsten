#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

TARGET_DIR="${TUNGSTEN_TEST_PLENARY:-${PROJECT_ROOT}/.test_deps/plenary.nvim}"

if [ -d "${TARGET_DIR}" ]; then
  echo "✔ plenary.nvim already installed at ${TARGET_DIR}"
  exit 0
fi

mkdir -p "$(dirname "${TARGET_DIR}")"

echo "Cloning plenary.nvim into ${TARGET_DIR}..."

git clone --depth 1 https://github.com/nvim-lua/plenary.nvim "${TARGET_DIR}"

echo "✔ plenary.nvim installed"
