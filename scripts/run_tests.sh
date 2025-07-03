#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT=$(cd "$(dirname "$0")/.." && pwd)
NVIM_BIN=${NVIM_BIN:-}

if [[ -z "$NVIM_BIN" ]]; then
  if command -v nvim >/dev/null 2>&1; then
    NVIM_BIN=$(command -v nvim)
  else
    sudo apt-get update
    sudo apt-get install -y neovim luarocks
    NVIM_BIN=$(command -v nvim)
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

ROCKTREE="$HOME/.local"
luarocks install --tree="$ROCKTREE" vusted
luarocks install --tree="$ROCKTREE" luacheck
luarocks install --tree="$ROCKTREE" luafilesystem
luarocks install --tree="$ROCKTREE" penlight
luarocks install --tree="$ROCKTREE" lpeg
luarocks install --tree="$ROCKTREE" plenary.nvim
export PATH="$ROCKTREE/bin:$PATH"
DEFAULT_LUA_PATH=$(lua5.1 -e 'print(package.path)')
DEFAULT_LUA_CPATH=$(lua5.1 -e 'print(package.cpath)')
export LUA_PATH="$(luarocks --tree="$ROCKTREE" path --lua-version=5.1 --lr-path);$DEFAULT_LUA_PATH"
export LUA_CPATH="$(luarocks --tree="$ROCKTREE" path --lua-version=5.1 --lr-cpath);$DEFAULT_LUA_CPATH"

export TUNGSTEN_PROJECT_ROOT="$PROJECT_ROOT"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_STATE_HOME="$HOME/.local/state"

"$NVIM_BIN" --headless \
  -u "$PROJECT_ROOT/tests/minimal_init.lua" \
  -c "PlenaryBustedDirectory $PROJECT_ROOT/tests { exit = true }"


