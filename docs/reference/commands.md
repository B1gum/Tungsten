# Command Reference

This document serves as a dictionary of the mathematical operations and commands available in Tungsten.

Most commands in Tungsten operate on a **Visual Selection**. To use them, highlight the relevant LaTeX or mathematical syntax in your buffer and execute the command.

## Core & Arithmetic

These commands handle general expression manipulation and evaluation.

| Command | Description |
| :--- | :--- |
| **`:TungstenEvaluate`** | Evaluates the current selection. This is the primary entry point for arithmetic, calculus (derivatives/integrals), and variable assignment. |
| **`:TungstenSimplify`** | Attempts to simplify the selected algebraic expression. |
| **`:TungstenFactor`** | Computes the factors of the selected polynomial or integer. |

### Usage Examples

**Evaluate**
* **Signature:** `:TungstenEvaluate` (on selection)
* **Input:** `3 \cdot 5`
* **Output:** `15`
* **Note:** If the selection contains an assignment operator (e.g., `x := 5`), it defines a persistent variable.

**Simplify**
* **Signature:** `:TungstenSimplify` (on selection)
* **Input:** `2x + 3x`
* **Output:** `5x`

**Factor**
* **Signature:** `:TungstenFactor` (on selection)
* **Input:** `x^2 + 2x + 1`
* **Output:** `(x+1)^2`

> **See Also:** [Arithmetic Domains](../domains/algebra.md), [Calculus](../domains/calculus.md)

---

## Linear Algebra

Commands specifically designed for matrix and vector operations.

| Command | Description | Note |
| :--- | :--- | :--- |
| **`:TungstenGaussEliminate`** | Performs Gaussian elimination on a matrix (Row Reduce). | Returns a row-reduced matrix |
| **`:TungstenRank`** | Calculates the rank of a matrix. | |
| **`:TungstenLinearIndependent`** | Checks if a set of vectors or a matrix's cols are linearly independent. | Returns `True`, `False`, or `Undetermined`. |
| **`:TungstenEigenvalue`** | Computes the eigenvalues of a matrix. | |
| **`:TungstenEigenvector`** | Computes the eigenvectors of a matrix. | |
| **`:TungstenEigensystem`** | Computes both eigenvalues and eigenvectors. | |

### Usage Examples

**Gauss Eliminate**
* **Signature:** `:TungstenGaussEliminate` (on matrix selection)
* **Input:** `\begin{pmatrix} 1 & 2 \\ 3 & 4 \end{pmatrix}`
* **Output:** `\begin{pmatrix} 1 & 0 \\ 0 & 1 \end{pmatrix}`

**Linear Independence**
* **Signature:** `:TungstenLinearIndependent` (on list of vectors or matrix)
* **Input:** `\begin{pmatrix} 1 & 2 \\ 3 & 4 \end{pmatrix}`
* **Output:** `True`

**Eigensystem**
* **Signature:** `:TungstenEigensystem` (on matrix selection)
* **Input:** `\begin{pmatrix} 2 & 0 \\ 0 & 1 \\ \end{pmatrix}`
* **Output:** `\left( \begin{array}{cc}  2 & 1 \\  \{1,0\} & \{0,1\} \\ \end{array} \right) `

> **See Also:** [Linear Algebra](../domains/linear-algebra.md)

---

## Differential Equations

Commands for solving and analyzing Ordinary Differential Equations (ODEs).

| Command | Description |
| :--- | :--- |
| **`:TungstenSolveODE`** | Solves a single ODE or a system of ODEs. |
| **`:TungstenWronskian`** | Computes the Wronskian determinant of a set of functions. |
| **`:TungstenLaplace`** | Computes the Laplace transform of an expression. |
| **`:TungstenInverseLaplace`** | Computes the Inverse Laplace transform. |
| **`:TungstenConvolve`** | Computes the convolution of two functions. |

### Usage Examples

**Solve ODE**
* **Signature:** `:TungstenSolveODE` (on equation or system)
* **Input:** `y'' + y = 0`
* **Output:** `y(x) = C_1 \sin(x) + C_2 \cos(x)`

**Laplace Transform**
* **Signature:** `:TungstenLaplace` (on expression)
* **Input:** `t^2`
* **Output:** `\frac{2}{s^3}`

> **See Also:** [Differential Equations](../domains/differential-equations.md)

---

## Plotting

Commands for generating visualizations.

| Command | Description |
| :--- | :--- |
| **`:TungstenPlot`** | Generates a standard 2D plot from the selected function. |
| **`:TungstenPlotAdvanced`** | Opens a UI window to configure advanced plot options (ranges, labels, etc). |
| **`:TungstenPlotParametric`** | Opens a UI window specifically for configuring parametric plots. |
| **`:TungstenPlotQueue`** | Displays the status of active and pending plot jobs. |
| **`:TungstenPlotCancel`** | Cancels the most recent or specific plot job. |
| **`:TungstenPlotCheck`** | Checks for required dependencies (Python/Matplotlib or Wolfram). |

### Usage Examples

**Simple Plot**
* **Signature:** `:TungstenPlot` (on expression)
* **Input:** `\sin(x)`
* **Output:** Plot of `\sin(x)` inserted into the buffer or shown in an external viewer depending on your [Configuration](config.md).

**Check Dependencies**
* **Signature:** `:TungstenPlotCheck`
* **Output:** List of installed backends (Wolfram, Python, Numpy, SymPy, Matplotlib) and version status.

> **See Also:** [Plotting](../domains/plotting.md)
