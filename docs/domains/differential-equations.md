# Differential Equations

Tungsten provides support for solving and analyzing ordinary and partial differential equations through its differential equations domain. 

**Examples**:
```latex
  y'' + y = 0 \rightarrow \{\{Y(x)\to c_1 \cos (x)+c_2 \sin (x)\}\}
  \mathcal{L}\{ \sin(t) \} = \frac{1}{s^2+1}
  W(y_1, y_2) = y_1(x) y_2'(x)-y_2(x) y_1'(x)
```

## Solving ODEs

Tungsten is able to solve both linear and non-linear ordinary differential equations. 
To solve an ODE, visually select the equation, which must contain at least one derivative, and run the `:TungstenSolveODE` command.

Tungsten supports various notation styles for derivatives, including Leibniz (`\frac{\mathrm{d}y}{\mathrm{d}x}`), Lagrange (`y'`), and Newton (`\dot{y}`).
These various notation styles can be mixed as shown underneath:
See the [Calculus Domain](calculus.md) for more information on this.

**Example**:
```latex
  \frac{\mathrm{d}^2y}{\mathrm{d}x^2} + y' = e^{x} = \left\{\left\{Y(x)\to \frac{e^x}{2}+c_1 \left(-e^{-x}\right)+c_2\right\}\right\}
```

### Initial Value Problems

You can specify initial or boundary conditions by including them in the selection, separated by a semicolon or `\\`.

**Example**:


## Solving PDEs

## Systems of ODEs

## Systems of PDEs

## Laplace Transforms

## Inverse Laplace Transforms

## Wronskians and Convolutions
