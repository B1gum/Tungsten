# Installation

This guide covers the prerequisites and steps to install **Tungsten** and set up its dependencies.

## Prerequisites

### Neovim Version
  - **Neovim 0.10.0** or higher.

### Neovim dependencies
- [nvim-lua/plenary.nvim](https://github.com/nvim-lua/plenary.nvim): required for asynchronous job handling and utility functions.

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

## Install

### Using lazy.nvim

```lua
{
  "B1gum/Tungsten",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-telescope/telescope.nvim", -- Optional
    "folke/which-key.nvim", -- Optional
  },
  build = "./scripts/install_python_deps.sh", -- This automates the packaging!
  opts = {
    -- Configuration options
  },
}
```

### Using packer.nvim
```lua
use({
  "B1gum/Tungsten",
  requires = {
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

## Verification
To verify that Tungsten is correctly installed:
  1. Open Neovim
  1. Run the command `:TungstenStatus`
  1. A status window should open, displaying the current job status (`Tungsten: No active jobs`) if you do not have any running jobs.

Alternatively, you can test a simple evaluation:
  1. Type `1+1` in a buffer.
  1. Visually select the text.
  1. Run `:TungstenEvaluate`. The result `2` should be inserted.
