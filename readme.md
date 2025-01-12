# Tungsten

**Tungsten** is a Neovim plugin that seamlessly integrates Wolfram functionalities directly into your editor. Includes capabilities like equation solving, plotting, partial derivatives, and more—all within Neovim.

## Features

- **Equation Solving:** Solve single equations, systems of equations, PDEs, and ODEs.
- **Plotting:** Generate 2D and 3D plots with extensive customization options.
- **Calculus Operations:** Perform differentiation (including partial derivatives), integration, and summations.
- **Simplifying Expressions:** Easily handle simplification of expressions written in LaTex-syntax
- **Imaginary Units:** Support for complex numbers and imaginary units.

## Installation

You can install **Tungsten** using your preferred Neovim plugin manager. Please refer to your plugin manager's documentation for specific installation instructions.


### Using packer.nvim

```lua
use 'B1gum/WolframFlow'
```

### Using lazy.nvim
Add the following to your lazy.nvim setup configuration:

```lua
require('lazy').setup({
  {
    'B1gum/WolframFlow',
    config = function()
      -- Plugin configuration goes here
    end
  }
})
```


## Usage

After installation, **Tungsten** provides several commands to enhance your mathematical computations within Neovim:

- `:TungstenAutoEval` – Evaluate expression symbolically.
– `:TungstenAutoEvalNumeric` – Evaluate expression numerically
- `:TungstenSolve` – Solve for variable in a single equation.
- `:TungstenSolveSystem` – Solve systems of equations.
- `:TungstenRoot` – Find roots of equations.
- `:TungstenPlot` – Generate plots.
- `:TungstenTaylor` – Generate a Taylor expansion.


### Example: Solving an Equation

1. **Select the Equation and Variable:**
   - Visually select the equation and specify the variable, e.g., `2x + 4 = 10, x`.

2. **Run the Command:**
   - Execute `:TungstenSolve`.

3. **View the Solution:**
   - The solution (`x = 3.`) will be appended below your selection.

## Contributing

Contributions are welcome! Please fork the repository and submit a pull request for any enhancements or bug fixes.

## License

This project is licensed under the [MIT License](LICENSE).

## Contact

For any questions or suggestions, feel free to open an issue or contact [B1gum](https://github.com/B1gum).

