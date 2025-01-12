# WolframFlow

**WolframFlow** is a Neovim plugin that seamlessly integrates Wolfram functionalities directly into your editor. Empower your workflow with capabilities like equation solving, plotting, partial derivatives, root-finding, unit conversions, and more—all within Neovim.

## Features

- **Equation Solving:** Solve single equations, systems of equations, PDEs, and ODEs.
- **Plotting:** Generate 2D and 3D plots with extensive customization options.
- **Calculus Operations:** Perform differentiation (including partial derivatives), integration, and summations.
- **Root-Finding:** Find roots using Wolfram's default algorithms with support for various methods.
- **Unit Conversion:** Convert units effortlessly, integrating with SIunitx for LaTeX support.
- **Persistent Sessions:** Maintain a continuous Wolfram kernel session for stateful computations.
- **Imaginary Units:** Support for complex numbers and imaginary units.
- **Extensible:** Modular design allowing easy addition of new functionalities.

## Installation

You can install **WolframFlow** using your preferred Neovim plugin manager. Please refer to your plugin manager's documentation for specific installation instructions.

## Usage

After installation, **WolframFlow** provides several commands to enhance your mathematical computations within Neovim:

- `:WolframSolve` – Solve single equations.
- `:WolframSolveSystem` – Solve systems of equations.
- `:WolframRoot` – Find roots of equations.
- `:WolframUnitsConvert` – Convert units.
- `:WolframPlot` – Generate plots.

### Example: Solving an Equation

1. **Select the Equation and Variable:**
   - Visually select the equation and specify the variable, e.g., `2x + 4 = 10, x`.

2. **Run the Command:**
   - Execute `:WolframSolve`.

3. **View the Solution:**
   - The solution (`x = 3.`) will be appended below your selection.

## Contributing

Contributions are welcome! Please fork the repository and submit a pull request for any enhancements or bug fixes.

## License

This project is licensed under the [MIT License](LICENSE).

## Contact

For any questions or suggestions, feel free to open an issue or contact [Noah Rahbek Bigum Hansen](https://github.com/B1gum).

