# Syntax Reference

Tungsten uses a custom parser that supports a mix of standard LaTeX syntax and intuitive shorthand common in programming or handwritten math.

## Variables and Constant## Quick Reference Cheatsheet

| Category | Input Example | Notes |
| :--- | :--- | :--- |
| **Arithmetic** | `1 + 2 * 3` | Standard order of operations applies |
| **Exponents** | `x^2`, `e^{x+1}` | Use `{}` to group complex exponents. |
| **Fractions** | `\frac{a}{b}`, `a/b` | Both LaTeX and inline division are supported. |
| **Grouping** | `(a + b)c` | Parentheses `()` define scope. |
| **Functions** | `\sin(x)`, `f(x)`, `\ln x` | Standard function calls. |
| **Variables** | `x`, `vel`, `x1` | Must start with a letter. |
| **Greek** | `\alpha`, `\beta`, `\pi` | Standard LaTeX commands. |
| **Matrices** | `\begin{pmatrix}...\end{pmatrix}` | Supports `p`, `b`, and `v` matrix types. |
| **Vectors** | `\vec{v}`, `\mathbf{v}`, `\begin{pmatrix}...\end{pmatrix}` | Symbolic vector notation or as row or column matrix. |
| **Derivatives** | `\frac{d}{dx} x^2`, `f'`, `\dot{f}` | Multiple notations for differentiation. |
| **Integrals** | `\int_{0}^{\infty} e^{-x} dx` | Definite and indefinite integrals. |


## 1. Variables and Constants

Tungsten uses strict tokenization rules to distinguish between variables, numbers, and commands.

### Variable Naming
  - **Structure**: Variable names must begin with a letter (A-Z, a-z).
  - **Alphanumeric**: After the first letter, variables may contain digits or underscores.
    - ✅ Valid: `x`, `y_2`, `velocity`, `Area51`
    - ❌ Invalid: `1x` (starts with digit), `_x` (starts with underscore)
  - **Case Sensitivity**: `x` and `X` are treated as distinct variables.

### Greek Letters
Tungsten recognizes standard LaTeX commands for Greek letters. These are treated as symbolic entities distinct from standard variables.
  - **Syntax**: `\alpha`, `\beta`, `\Gamma`, `\omega`, etc.
  - **Usage**: They can be used anywhere a variable is used: `2\pi`, `\sin(\theta)`.

### Constants
Certain symbols are reserved or automatically recognized as mathematical constants depending on the backend:
  - `\pi` or `pi`
  - `e` (Euler's number)
  - `\infty` (Infinity)


## 2. Operators and Precedence

The parser adheres to standard mathematical precedence rules. When operators share the same precedence, associativity determines the order of evaluation.

| Precedence | Operator | Description | Associativity | Syntax Variants |
| :--- | :--- | :--- | :--- | :--- |
| **3 (Highest)** | `^` | Exponentiation | **Right** | `x^2`, `x^{y+1}` |
| **2** | `*` | Multiplication | **Left** | `*`, `\cdot`, `\times` |
| **2** | `/` | Division | **Left** | `/`, `\frac{num}{den}` |
| **1** | `+` | Addition | **Left** | `+` |
| **1** | `-` | Subtraction | **Left** | `-` |
| **0 (Lowest)** | `=` | Equality | **None** | `=`, `==`, `&=` |



### Important Notes on Operators:
  - **Right Associativity** (`^`): `2^3^4` is parsed as `2^(3^4)`, not `(2^3)^4`.
  - **Synonyms**: The parser treats `\cdot` (dot) and `\times` (cross) identically to `*` in scalar arithmetic contexts. However, in Linear Algebra contexts, they denote Dot Product and Cross Product respectively.


### Implicit Multiplication

You can often omit the multiplication operator, just like in handwritten math. The parser infers multiplication in the following cases:

  - **Number + Variable**: `2x` becomes `2 * x`
  - **Variable + Variable**: `x y` becomes `x * y` (*Note*: `xy` is parsed as a single variable named "xy". Use a space to separate them.)
  - **Group + Variable**: `(a+b)x` becomes `(a+b) * x`
  - **Number + Greek**: `2\pi` becomes `2 * \pi`
  - **Function Chains**: `\sin(x)\cos(y)` becomes `\sin(x) * \cos(y)`

## 3. Functions and Grouping

### Function Syntax
  - **Standard Calls**: `name(arg1, arg2)`
    - Example: `f(x)`, `sin(x)`
  - **LaTeX Style Calls**: `\command{arg}`
    - Example: `\sqrt{x}`, `\frac{1}{2}`
  - **Parenthesis-less Calls**: For common log/trig functions, parentheses can sometimes be omitted if the argument is a single token.
    - `\ln x` is valid.
    - `\sin \theta` is valid.
    - `\cos(x + 1)` is valid

### Grouping Symbols
  - **Parentheses** `()`: Used for standard mathematical grouping and function arguments.
  - **Braces** `{}`: Used strictly for LaTeX command arguments (e.g., `x^{2}`, `\frac{a}{b}`).
  - **Brackets** `[]`: Often used for defining lists or specific matrix notations, though `()` is preferred for arithmetic precedence.


## 4. Syntax Limitations and Edge Cases

To ensure the parser behaves predictably, certain inputs that might look "okay" to a human are strictly invalid.

### 1. Decimal Formatting
Numbers must have a leading digit before the decimal point.
  - ✅ Correct: `0.5`
  - ❌ Incorrect: `.5` (This will fail to parse as a number)

### 2. Whitespace and Implicit Multiplication
As noted in section 3, whitespace is semantically significant for variables.
  - `xy` $\rightarrow$ Variable named "xy"
  - `x y` $\rightarrow$ Multiplication `x * y`

### 3. LaTeX Environment Closure
All LaTeX environments must be perfectly balanced.
  - ❌ `\begin{pmatrix} 1 & 2` (Missing end tag)
  - ❌ `\frac{1}{2` (Unmatched brace)

### 4. Argument Bracing
LaTeX commands like `\frac` and `\sqrt` expect arguments in braces `{}`.
  - ✅ `x^{10}`
  - ⚠️ `x^10` (Parses as `(x^1) * 0` like it would in standard LaTeX)
  - ❌ `\frac 1 2` (Arguments must be braced: `\frac{1}{2}`)

### 5. Multi-line Inputs
For systems of equations or similar you are able to use the standard LaTeX-construction of `&=` and `\\`. `&=` is parsed as `=` and `\\` is parsed as beginning a new expression.
```latex
x + y &= 1 \\
x - y &= 2
```
You are also able to use semi-colons `;` between expressions:
```latex
x + y = 1;
x - y = 2
```

---

**Found syntax that should work but doesn't?**
The world of mathematical notation is vast. If you encounter valid mathematical notation that Tungsten fails to parse, please file a [bug report or feature request](https://github.com/B1gum/Tungsten/issues).
