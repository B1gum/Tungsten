#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT=$(cd "$(dirname "$0")/.." && pwd)
NVIM_BIN=${NVIM_BIN:-}

# Determine Neovim executable or bootstrap a local copy
if [[ -z "$NVIM_BIN" ]]; then
  if command -v nvim >/dev/null 2>&1; then
    NVIM_BIN=$(command -v nvim)
  else
    NVIM_DIR="$PROJECT_ROOT/.deps/nvim"
    NVIM_BIN="$NVIM_DIR/bin/nvim"
    if [[ ! -x "$NVIM_BIN" ]]; then
      echo "Neovim not found, downloading nightly build..."
      mkdir -p "$NVIM_DIR"
      curl -L https://github.com/neovim/neovim/releases/latest/download/nvim-linux64.tar.gz |
        tar xz --strip-components=1 -C "$NVIM_DIR"
    fi
  fi
fi

# Bootstrap plugin dependencies into a temporary HOME
TEST_HOME="${TEST_HOME:-$PROJECT_ROOT/.test_home}"
export HOME="$TEST_HOME"
PLUGIN_BASE="$HOME/.local/share/nvim/lazy"
mkdir -p "$PLUGIN_BASE"

clone_if_missing() {
  local repo="$1" dst="$2"
  if [[ ! -d "$dst" ]]; then
    git clone --depth 1 "$repo" "$dst"
  fi
}

clone_if_missing https://github.com/nvim-lua/plenary.nvim "$PLUGIN_BASE/plenary.nvim"
clone_if_missing https://github.com/folke/which-key.nvim "$PLUGIN_BASE/which-key.nvim"
clone_if_missing https://github.com/nvim-telescope/telescope.nvim "$PLUGIN_BASE/telescope.nvim"

export TUNGSTEN_PROJECT_ROOT="$PROJECT_ROOT"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_STATE_HOME="$HOME/.local/state"

"$NVIM_BIN" --headless \
  -u "$PROJECT_ROOT/tests/minimal_init.lua" \
  -c "PlenaryBustedDirectory $PROJECT_ROOT/tests { minimal_init = '$PROJECT_ROOT/tests/minimal_init.lua' }"
