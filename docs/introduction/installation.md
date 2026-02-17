# Installation

This guide covers the prerequisites and steps to install **Tungsten** and set up its dependencies.

## Prerequisites

### Neovim Version
  - **Neovim 0.8.0** or higher.

### lua dependencies

#### Neovim plugins:
- [nvim-lua/plenary.nvim](https://github.com/nvim-lua/plenary.nvim): required for asynchronous job handling and utility functions.

#### LuaRocks packages:
- [lpeg](https://luarocks.org/modules/gvvaughan/lpeg): used for parsing LaTeX input.
- [luafilesystem](https://luarocks.org/modules/hisham/luafilesystem): used for file system operations in plotting.
- [penlight](https://luarocks.org/modules/steved/penlight): provides utility libraries (filesystem, paths) for plotting.

### System Dependencies
Tungsten relies on external tools to perform calculations and render plots. Depending on your preferred backend, ensure the following are installed:

#### Wolfram Backend (Default)
To use the Wolfram backend, you must install the Wolfram Engine and its scripting interface, WolframScript.
See the [Wolfram Engine installation guide](https://www.wolfram.com/engine/) for download and activation instructions.

#### Python Backend
The Python backend uses standard scientific libraries for calculations and plotting. You must have **Python 3** installed along with the following packages:
  - **sympy**: For symbolic mathematics and solving equations.
  - **numpy**: For numerical arrays and math operations.
  - **matplotlib**: For generating 2D and 3D plots.

You can install these dependencies via pip:
```bash
pip install sympy numpy matplotlib
```

## Installation
Tungsten uses the LuaRocks dependency `lpeg` for its parser.  
If you use `lazy.nvim`, these can be installed automatically via `vhyrro/luarocks.nvim`.

### Using lazy.nvim
## Install

Tungsten uses the LuaRocks dependency `lpeg` for its parser. 
If you use `lazy.nvim`, these can be installed automatically via `vhyrro/luarocks.nvim`.

### Using lazy.nvim

```lua
{
  {
    "vhyrro/luarocks.nvim",
    priority = 1000,
    config = true,
  },
  {
    "B1gum/Tungsten",
    dependencies = {
      "vhyrro/luarocks.nvim",
      "nvim-lua/plenary.nvim",
      "nvim-telescope/telescope.nvim", -- Optional
      "folke/which-key.nvim", -- Optional
    },
    build = "./scripts/install_python_deps.sh", -- This automates the packaging!
    opts = {
      -- Configuration options
    },
    rocks = {
      "lpeg",
      "luafilesystem",
      "penlight",
    },
  },
}
```

### Using packer.nvim
Note: `packer.nvim` does not install LuaRocks dependencies automatically on its own.
Recommended: install `vhyrro/luarocks.nvim` and ensure luarocks is available on your PATH.

```lua
use({
  "vhyrro/luarocks.nvim",
  config = function()
    require("luarocks").setup({})
  end,
})

use({
  "B1gum/Tungsten",
  requires = {
    "vhyrro/luarocks.nvim",
    "nvim-lua/plenary.nvim",
    "nvim-telescope/telescope.nvim", -- Optional
    "folke/which-key.nvim", -- Optional
  },
  run = "./scripts/install_python_deps.sh",
  config = function()
    require("tungsten").setup({
      -- Configuration options
    })
  end,
})

```

If you prefer installing rocks manually instead of using luarocks.nvim:
```sh
luarocks install lpeg
luarocks install luafilesystem
luarocks install penlight
```

## Verification
To verify that Tungsten is correctly installed:
  1. Open Neovim
  1. Run the command `:TungstenStatus`
  1. A status window should open, displaying the current job status (`Tungsten: No active jobs`) if you do not have any running jobs.

Alternatively, you can test a simple evaluation:
  1. Type `1+1` in a buffer.
  1. Visually select the text.
  1. Run `:TungstenEvaluate`. The result `2` should be inserted.
