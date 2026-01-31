![Build Status](https://img.shields.io/github/actions/workflow/status/B1gum/Tungsten/ci.yml?branch=main)
![License](https://img.shields.io/github/license/B1gum/Tungsten)
![Latest Release](https://img.shields.io/github/v/release/B1gum/Tungsten)
[![codecov](https://codecov.io/github/B1gum/Tungsten/graph/badge.svg?token=M34Z3LCTCS)](https://codecov.io/github/B1gum/Tungsten)
# Tungsten
**Tungsten** is a Neovim plugin that seamlessly integrates Wolfram capabilities directly into your editor. It keeps you in flow by letting you evaluate LaTeX-formatted math, solve equations, generate plots, and much more without leaving your buffer.


## Documentation

- **[Introduction](docs/introduction/index.md)**
  Start here for installation, configuration, and a quick tour of the plugin's philosophy.
- **[Domains](docs/domains/index.md)**
  Dive into specialized domains including Algebra, Calculus, Differential Equations, Linear Algebra, and Plotting.
- **[Reference](docs/reference/index.md)**
  Detailed API documentation, command lists, syntax grammar specifications, and backend integration details.
- **[Table of Contents](docs/toc.md)**
  An overview of every documentation page.

## Key Features

* **Seamless Workflow**: Evaluate LaTeX-formatted math without leaving Neovim.
* **Specialized Domains**: Purpose-built handling for Arithmetic, Calculus, Linear Algebra, and more.
* **Rich Plotting**: Generate 2D curves, 3D surfaces, and scatter plots directly from your code.
* **LaTeX Native**: Write expressions using standard LaTeX syntax and shorthand.

## Quick Install
For `lazy.nvim` users:

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
    opts = {
      -- Configuration options
    },
    rocks = {
      "lpeg",
      "lpeglabel",
      "luafilesystem",
      "penlight",
    },
  },
}
```
Need more detail or using a different package manager? See the [Installation Guide](docs/introduction/installation.md).

Tungsten relies on the Wolfram Engine and WolframScript. Follow the full walkthrough in the [Installation Guide](docs/introduction/installation.md) to:

1. Download and install the Wolfram Engine.
2. Install WolframScript.
3. Activate a free Wolfram Engine license.

## Getting Started

- Learn the workflow in the [Quickstart Guide](docs/introduction/quickstart.md).
- Customize Tungsten in the [Configuration Guide](docs/introduction/configuration.md).
- Explore domain-specific syntax in [Domains](docs/domains/index.md).

## Contributing

Contributions are welcome! Please follow the guidelines in the [Contributing Guide](docs/introduction/overview.md) and open issues or PRs as needed.

## Running Tests

Run the test suite with:

```
make test
```

The test helper will install Lua dependencies via `luarocks` and clone
`plenary.nvim` into `~/.local/share/nvim/lazy` if it is missing.

### Linting and Formatting
To maintain code quality, we enforce linting and formatting. You can run these checks locally:

- **Linting**: Run `make lint` to check for code issues using `luacheck`.
- **Formatting Check**: Run `make fmt-check` to see if your code matches the style guide.
- **Auto-format**: Run `make fmt` to automatically format your code using `stylua`.
- **All**: Run `make all` to automatically format, lint and run the tests.

## License

This project is licensed under the [MIT License](LICENSE).

## Contact

For any questions or suggestions, feel free to open an issue or contact [B1gum](https://github.com/B1gum).

