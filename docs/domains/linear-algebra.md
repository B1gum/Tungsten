# Linear Algebra

Tungsten's linear algebra domain allows for parsing of parsing of vectors and martrices and some of their associated operations.
The linear algebra domain makes a distinction between `\cdot` and `\times` which are taken to mean the dot product and the cross product, respectively, when one or more of the operands are vectors and/or matrices.

```latex
\begin{pmatrix} 1 & 2 \\ 3 & 4 \end{pmatrix} \cdot \begin{pmatrix} 1 \\ 0 \end{pmatrix} = \{1,3\}

\begin{pmatrix} 1 \\ 2 \\ 3 \end{pmatrix} \times \begin{pmatrix} 4 \\ 5 \\ 6 \end{pmatrix} = \begin{pmatrix} -3 \\ 6 \\ -3 \end{pmatrix} = \{-3,6,-3\}=\left(
    \begin{array}{c}
        -3 \\
        6 \\
        -3 \\
    \end{array}
\right)

\det\left(\begin{pmatrix} 1 & 2 \\ 3 & 4 \end{pmatrix}\right) = -2
```

## Vectors and Matrices

Tungsten parses the standard LaTeX matrix environments `\pmatrix` and `\bmatrix`. This means that either of the following are valid expressions in Tungsten.
```latex
A := \begin{bmatrix} 1 & 3 & 4\\ 4 & 2 & 1\\ 2 & 3 & 1\\ \end{bmatrix}

B := \begin{pmatrix} 1\\ 8\\ \end{pmatrix}
```

In Tungsten a vector is defined as a matrix with only one row or column. 

## Basic Operations

### Addition and Subtraction

You are also able to subtract and add matrices or vectors using `:TungstenEvaluate`.

Adding or subtracting a constant from a vector or matrix is parsed as an element-wise operation as:
```latex
\begin{pmatrix}
    1 & 2\\
    2 & 2\\
\end{pmatrix} - 2 = \left(\begin{array}{cc}
   -1 & 0 \\
   0 & 0 \\
\end{array}\right)
```

Addition and subtraction between matrices or vectors works as
```latex
\begin{pmatrix}
    1 & 2\\
    3 & 4\\
\end{pmatrix} + \begin{pmatrix}
    2 & 3\\
    3 & 4\\
\end{pmatrix} = \left(
\begin{array}{cc}
    3 & 5 \\
    6 & 8 \\
\end{array}\right)

\begin{bmatrix}
    1 & 2 & 3\\
\end{bmatrix} + \begin{bmatrix}
    2 & 3 & 4\\
\end{bmatrix} = \left(
\begin{array}{ccc}
    3 & 5 & 7 \\
\end{array}\right)
```


### Multiplication and Products

As mentioned above, the linear algebra domain overrides the multiplication defaults of the [arithmetic and algebra domain](algebra.md).

**Matrix Multiplication**: Using `\cdot` between two matrices (or a matrix and a vector) results in standard matrix multiplication.

**Examples**:
```latex
\begin{pmatrix}
    1 & 2\\
    3 & 4\\
\end{pmatrix} \cdot \begin{pmatrix}
    1 & 3\\
    2 & 4\\
\end{pmatrix} = \left(\begin{array}{cc}
    5 & 11 \\
    11 & 25 \\
\end{array}\right)

\begin{bmatrix}
    g & h & i\\
\end{bmatrix} \cdot \begin{bmatrix}
    a & b\\
    c & d\\
    e & f\\
\end{bmatrix} = \{a g+c h+e i,b g+d h+f i\}
```

**Dot Product**: Using `\cdot` between two vectors calculates the dot or scalar product.

**Example**:
```latex
\begin{bmatrix}
    a & b \\
\end{bmatrix} \cdot \begin{bmatrix}
    c\\
    d\\
\end{bmatrix}  = a c+d b

\begin{bmatrix}
    8\\
    6\\
    1\\
\end{bmatrix} \cdot \begin{bmatrix}
    2 & 3 & 1\\
\end{bmatrix} = 35
```

**Cross Product**: Using `\times` between two vectors calculates the cross product.

**Example**:
```latex
\begin{bmatrix}
    a & b & c\\
\end{bmatrix} \times \begin{bmatrix}
    d\\
    e\\
    f\\
\end{bmatrix} = \{b f-e c,c d-a f,e a-b d\}

\begin{bmatrix}
    a & b & c\\
\end{bmatrix}\times \begin{bmatrix}
    d & e & f\\
\end{bmatrix}  = \{b f-e c,c d-a f,e a-b d\}

\begin{bmatrix}
    2 & 2 & 4\\
\end{bmatrix} \times \begin{bmatrix}
    1\\
    6\\
    3\\
\end{bmatrix} = \{-18,-2,10\}
```

*Note*: The Wolfram engine does not differentiate between row and column-vectors, hence, the cross product between a row and a column vector is parsed the same as that between two row or two column vectors. This is not true for addition and subtraction between vectors and matrices, where Wolfram respects their directionality. 



### Norms and Determinants

Calculating the norm of a vector and the determinant of a matrix is supported directly via `:TungstenEvaluate`. 

The norm of a vector is found, simply by encapsulating the vector in any of `|...|`, `\|...\|`, or `\left|...\right|`, visually selecting the expression and running `:TungstenEvaluate` as

```latex
|\begin{bmatrix}
    1 & 2 & 3\\
\end{bmatrix}| = \sqrt{14}

\|\begin{bmatrix}
    1 & 2 & 3\\
\end{bmatrix} \| = \sqrt{14}

\left| \begin{bmatrix}
    1 & 2 & 3\\
\end{bmatrix} \right| = \sqrt{14}
```

To find the determinant of a matrix, simply write the matrix using `\begin{vmatrix} ... \end{vmatrix}`, encapsulate a `bmatrix` or `pmatrix` in `|...|` delimiters, or encapsulating a `bmatrix` or `pmatrix` environment in `\det(...)`, visually select it, and run the `:TungstenEvaluate` command.

**Examples**:
```latex
\begin{vmatrix}
    1 & 3\\
    2 & 4\\
\end{vmatrix} = -2

\left| \begin{bmatrix}
    1 & 3 & 4\\
    2 & 3 & 6\\
\end{bmatrix} \right| = \sqrt{\frac{1}{2} \left(75+\sqrt{5429}\right)}

\det\left( \begin{bmatrix}
    1 & a\\
    b & 4\\
\end{bmatrix}\right) = 4-a b
```

### Transposed and Inverse Matrices

You can transpose a matrix or vector using the `^\intercal` or `^T` syntax and running `:TungstenEvaluate` as:

```latex
\begin{bmatrix}
    1 & 2 & 3\\
    4 & 5 & 6\\
    7 & 8 & 9\\
\end{bmatrix}^{T} = \left(\begin{array}{ccc}
    1 & 4 & 7 \\
    2 & 5 & 8 \\
    3 & 6 & 9 \\
\end{array}\right)

\begin{bmatrix}
    a & b & c\\
\end{bmatrix}^{\intercal} = \left(\begin{array}{c}
    a \\
    b \\
    c \\
\end{array}\right)
```

The inverse of a square matrix is found using `^{-1}` syntax and running `:TungstenEvaluate` as:
```latex
\begin{pmatrix}
    1 & 2\\
    3 & 4\\
\end{pmatrix}^{-1} = \left(\begin{array}{cc}
    -2 & 1 \\
    \frac{3}{2} & -\frac{1}{2} \\
\end{array}\right)

\begin{pmatrix}
    a & b\\
    c & d\\
\end{pmatrix}^{-1} = \left(\begin{array}{cc}
    \frac{d}{a d-b c} & -\frac{b}{a d-b c} \\
    -\frac{c}{a d-b c} & \frac{a}{a d-b c} \\
\end{array}\right)
```


## Matrix Analysis

Tungsten also provides specific commands for analyzing the properties of matrices.

### Gauss Elimination

To perform Gaussian elimination (also called row reduction) on a matrix, visually select it and run the `:TungstenGaussEliminate` command.
The result is inserted as `<Matrix> \rightarrow <ReducedMatrix>`.

**Example**:
```latex
\begin{bmatrix}
    1 & 2 & 3\\
    4 & 5 & 6\\
\end{bmatrix} \rightarrow \left(\begin{array}{ccc}
    1 & 0 & -1 \\
    0 & 1 & 2 \\
\end{array}\right)
```

### Rank

To find the rank of a matrix, visually select it and run `:TungstenRank`.

**Example**:
```latex
\begin{pmatrix}
    1 & 2\\
    2 & 4\\
\end{pmatrix} \rightarrow 1.
```

### Linear Dependence

You can check if a matrix (columns) or a list of (`;`-separated) vectors are linearly independent using the `:TungstenLinearIndependent` command.
The output will be either `True` or `False`.

**Example**:
```latex
\begin{pmatrix}
    1 & 2\\
    2 & 4\\
\end{pmatrix} = False

\begin{pmatrix}
    1\\ 
    0\\
\end{pmatrix}; \begin{pmatrix}
    0\\
    1\\
\end{pmatrix} = True
```

### Eigenvalues and Eigenvectors

Tungsten also allows you to compute the spectral properties of matrices using the commands:

  - `:TungstenEigenvalue`: Computes the eigenvalues.
  - `:TungstenEigenvector`: Computes the eigenvectors.
  - `TungstenEigensystem`: Computes both eigenvalues and corresponding eigenvectors.

These are shown in order in the following example:

```latex
\begin{pmatrix}
    1 & 0\\
    0 & 2\\
\end{pmatrix} \rightarrow \{2,1\}

\begin{pmatrix}
    1 & 0\\
    0 & 2\\
\end{pmatrix} \rightarrow \left(\begin{array}{cc}
    0 & 1 \\
    1 & 0 \\
\end{array}\right)

\begin{pmatrix}
    1 & 0\\
    0 & 2\\
\end{pmatrix}  \rightarrow \left(\begin{array}{cc}
    2 & 1 \\
    \{0,1\} & \{1,0\} \\
\end{array}\right)
```
