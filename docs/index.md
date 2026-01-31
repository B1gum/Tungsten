# Tungsten Documentation

**Tungsten** is a Neovim plugin that seamlessly integrates Wolfram functionalities directly into your editor. Designed to eliminate context switching, it brings powerful mathematical capabilities—including equation solving, symbolic calculus, and 3D plotting—right into your buffer using standard LaTeX syntax.

## Documentation

- **[Introduction](introduction/index.md)**
  New here? Start with installation, configuration, and a quick tour of the plugin's core philosophy.

- **[Domains](domains/index.md)**
  Deep dives into specialized domains including Algebra, Calculus, Differential Equations, Linear Algebra, and Plotting.

- **[Reference](reference/index.md)**
  Detailed API documentation, command lists, syntax grammar specifications, and backend integration specifics.

## Key Features

* **Seamless Workflow**: Evaluate LaTeX-formatted math without leaving Neovim.
* **Specialized Domains**: specialized handling for Arithmetic, Calculus, Linear Algebra, and more.
* **Rich Plotting**: Generate 2D curves, 3D surfaces, and scatter plots directly from your code.
* **LaTeX Native**: Write mathematical expressions using standard LaTeX syntax and shorthand.

---
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

---
## Getting Started

- Learn the workflow in the [Quickstart Guide](docs/introduction/quickstart.md).
- Customize Tungsten in the [Configuration Guide](docs/introduction/configuration.md).
- Explore domain-specific syntax in [Domains](docs/domains/index.md).

---
## Contributing

Contributions are welcome! Please follow the guidelines in the [Contributing Guide](docs/introduction/overview.md) and open issues or PRs as needed.

---
## Running Tests

Run the test suite with:

```
make test
```

The test helper will install Lua dependencies via `luarocks` and clone `plenary.nvim` into `~/.local/share/nvim/lazy` if it is missing.


---
## License

This project is licensed under the [MIT License](LICENSE).

---
## Contact

For any questions or suggestions, feel free to open an issue or contact [B1gum](https://github.com/B1gum).


---
For an overview of all the documentation pages see the [Table of Contents](toc.md).
