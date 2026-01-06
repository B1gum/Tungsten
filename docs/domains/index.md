# Domains

Tungsten organizes its mathematical capabilities into specialized **domains**. Each domain is designed to handle specific types of LaTeX input, allowing the engine to intelligently switch between arithmetic, matrix operations, plotting, and symbolic calculus.

Below is an overview of the supported domains and their capabilities -- For detailed information please see the individual domain pages.

## [Arithmetic and Algebra](algebra.md)
The fundamental domain for everyday calculations. It handles:
* **Basic Operations**: Addition, subtraction, multiplication, and division.
* **Persistent Variables**: Defining variables (e.g., `a := 2`) that persist across evaluations.
* **Equation Solving**: Solving linear and non-linear equations and systems of equations.
* **Manipulation**: Simplifying and factoring algebraic expressions.

## [Calculus](calculus.md)
Provides symbolic evaluation for core calculus concepts using standard Leibniz, Lagrange, or Newton notation.
* **Derivatives**: Ordinary and partial derivatives.
* **Integrals**: Definite and indefinite integration.
* **Limits & Sums**: Evaluating limits (`\lim`) and summations (`\sum`).

## [Differential Equations](differential-equations.md)
A powerful domain for solving differential equations and performing integral transforms.
* **ODE & PDE Solvers**: Solves Ordinary and Partial Differential Equations, including Initial Value Problems (IVPs).
* **Systems**: Solves systems of ODEs and PDEs.
* **Transforms**: Calculates Laplace transforms, Inverse Laplace transforms, and Convolutions.

## [Linear Algebra](linear-algebra.md)
Dedicated to vector and matrix operations, distinguishing between dot products (`\cdot`) and cross products (`\times`).
* **Matrix Operations**: Multiplication, addition, inversion, and transposition.
* **Analysis**: Computing determinants, norms, rank, and linear independence.
* **Decompositions**: Gaussian elimination and finding eigenvalues/eigenvectors.

## [Plotting](plotting.md)
Visualizes mathematical expressions directly within your editor by generating 2D and 3D figures.
* **Smart Recognition**: Automatically detects explicit, implicit, parametric, and polar plots.
* **2D & 3D**: Supports curves, surfaces, and scatter plots.
* **Configuration**: Extensive options for ranges, styles, and multi-series plots.

## [Numerics](numerics.md)
Controls the precision mode of the engine.
* **Symbolic vs. Numeric**: Toggle between exact symbolic results (e.g., `\pi`, `\sqrt{2}`) and decimal approximations (e.g., `3.14159`, `1.414`).

## [Units](units.md)
Enables physical quantity calculations compatible with the `siunitx` LaTeX package.
* **Unit Arithmetic**: Add and multiply quantities with units (e.g., `\qty{5}{\m} + \qty{10}{\cm}`).
* **Angles & Formatting**: Handles angular degrees (`\ang`) and number formatting (`\num`).
