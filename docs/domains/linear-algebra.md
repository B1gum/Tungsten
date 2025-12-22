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

As mentioned above, the linear algebra domain overrides the multiplication defaults of the [arithmatics domain](arithmetics.md)

### Addition and Subtraction

### Multiplication and Products

### Norms and Determinants

### Transposes

## Matrix Analysis

### Gauss Elimination

### Rank

### Linear Dependence

### Eigenvalues and Eigenvectors
