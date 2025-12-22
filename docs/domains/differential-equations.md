# Differential Equations

Tungsten provides support for solving and analyzing ordinary and partial differential equations through its differential equations domain. 

**Examples**:
```latex
  y'' + y = 0 \rightarrow \{\{Y(x)\to c_1 \cos (x)+c_2 \sin (x)\}\}
  \mathcal{L}\{ \sin(t) \} = \frac{1}{s^2+1}
  W(y_1, y_2) = y_1(x) y_2'(x)-y_2(x) y_1'(x)
```

## Solving ODEs

Tungsten is able to solve both linear and non-linear ordinary differential equations (ODEs). 
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
```latex
  y'' + y = 0; y(0) = 1; y'(0) = 0 \rightarrow \{\{Y(x)\to \cos (x)\}\}
```


## Solving PDEs

Tungsten is also capable of parsing and solving partial differential equations (PDEs).
To solve a PDE follow the same procedure as you would when solving an ODE.
Tungsten automatically figures out if you are trying to solve an ODE or a PDE and delegates the job to the solver accordingly. 

You are able to mix different derivative notations in the same problem as:
```latex
  \frac{\partial y}{\partial x} + \frac{\partial y}{\partial t} = 0  \rightarrow \{\{Y(t,x)\to c_1(x-t)\}\}
  y' + \dot{y} = 0 \rightarrow \{\{Y(t,x)\to c_1(x-t)\}\}
  \frac{\partial y(x,t)}{\partial x} + \frac{\partial y(x,t)}{\partial t}  = 0 \rightarrow \{\{Y(x,t)\to c_1(t-x)\}\}
```



## Systems of ODEs

You are also able to solve system of ODEs using Tungsten. To do this, simply write up a system of ODEs either separated by `;` or `\\`, visually select the system of ODEs and run the `:TungstenSolveODESystem` command.

**Example**:
```latex
    \frac{\mathrm{d}x}{\mathrm{d}t} = x + y; \frac{\mathrm{d}y}{\mathrm{d}t} = 4 x + y  \rightarrow \left\{\left\{X(t)\to \frac{1}{2} c_1 e^{-t} \left(e^{4 t}+1\right)+\frac{1}{4} c_2 e^{-t} \left(e^{4 t}-1\right),Y(t)\to c_1 e^{-t} \left(e^{4 t}-1\right)+\frac{1}{2} c_2 e^{-t} \left(e^{4 t}+1\right)\right\}\right\}

  \frac{\mathrm{d}}{\mathrm{d}t} x &= x + y \\
  \frac{\mathrm{d}y}{\mathrm{d}t} &= 4x + y  \rightarrow \left\{\left\{X(t)\to \frac{1}{2} c_1 e^{-t} \left(e^{4 t}+1\right)+\frac{1}{4} c_2 e^{-t} \left(e^{4 t}-1\right),Y(t)\to c_1 e^{-t} \left(e^{4 t}-1\right)+\frac{1}{2} c_2 e^{-t} \left(e^{4 t}+1\right)\right\}\right\}

  \dot{x} &= x + y \\
  \dot{y} &= 4x + y  \rightarrow \left\{\left\{X(t)\to \frac{1}{2} c_1 e^{-t} \left(e^{4 t}+1\right)+\frac{1}{4} c_2 e^{-t} \left(e^{4 t}-1\right),Y(t)\to c_1 e^{-t} \left(e^{4 t}-1\right)+\frac{1}{2} c_2 e^{-t} \left(e^{4 t}+1\right)\right\}\right\}
```

You are also able to apply initial conditions, simply by adding these separated by either `;` or `\\` as is the case for IVP's with only one ODE.

**Example**:
```latex
    \dot{x} &= x + y \\
  \dot{y} &= 4x + y \\
  y(0) &= e^{t} \\
  x(0) &= e^{-t} \rightarrow \left\{\left\{X(t)\to \frac{1}{4} e^{-2 t} \left(-e^{2 t}+2 e^{4 t}+e^{6 t}+2\right),Y(t)\to \frac{1}{2} e^{-2 t} \left(e^{2 t}+2 e^{4 t}+e^{6 t}-2\right)\right\}\right\}
```

## Systems of PDEs

Some support for systems of PDEs is also present. Here, the syntax and method follows that for systems of ODEs, and you can once again separate equations using either `;` or `\\` and evaluate using the `:TungstenSolveODESystem` command. 

**Example**:
```latex
  \frac{\mathrm{d}u}{\mathrm{d}x} &= 2u \\
  \frac{\mathrm{d}v}{\mathrm{d}y} &= 3v  \rightarrow \left\{\left\{U(x,y)\to e^{2 x} c_1(y),V(x,y)\to e^{3 y} c_2(x)\right\}\right\}

  \frac{\mathrm{d}u(x,y)}{\mathrm{d}x} &= 2u(x,y) \\
  \frac{\mathrm{d}v(x,y)}{\mathrm{d}y} &= 3 v(x,y) \rightarrow \left\{\left\{U(x,y)\to e^{2 x} c_1(y),V(x,y)\to e^{3 y} c_2(x)\right\}\right\}


  \frac{\partial u}{\partial x} &= 2u \\
  \frac{\partial v}{\partial y} &= 3v \rightarrow \left\{\left\{U(x,y)\to e^{2 x} c_1(y),V(x,y)\to e^{3 y} c_2(x)\right\}\right\}

  \frac{\partial u(x,y)}{\partial x} &= 2u(x,y) \\
  \frac{\partial v(x,y)}{\partial y} &= 3v(x,y) \rightarrow \left\{\left\{U(x,y)\to e^{2 x} c_1(y),V(x,y)\to e^{3 y} c_2(x)\right\}\right\}

```

## Laplace Transforms and Inverse Laplace Transforms

It is also possible to do Laplace transforms and inverse Laplace transforms using Tungsten.
To find the Laplace transform of a function, simply write out the function in standard LaTeX-syntax, visually select it and run the `:TungstenLaplace` command. 

**Example**:
```latex
  1 \rightarrow \frac{1}{s}
  e^{-at} \rightarrow \frac{e^{-\text{at}}}{s}
```

Tungsten natively parses the heaviside step function (written as `u`) and the dirac-delta function (written as `\delta`) when doing Laplace transforms.

**Example**:
```latex
  u(t-a) \rightarrow \frac{e^{-a s} u (a)+u (-a)}{s}
  \delta(t-a) \rightarrow u (a) e^{-a s}
```

Inverse Laplace transforms are found in the same manner, by writing out an expression, visually selecting it and running the `:TungstenInverseLaplace` command.

**Example**:
```latex
  \frac{1}{s} \rightarrow 1
  \frac{e^{-at}}{s} \rightarrow e^{-\text{at}}

  \frac{\omega}{\omega^2 + s^2} \rightarrow \sin (\omega  t)
  \frac{s}{s^2 + \omega^2} \rightarrow \cos (\omega  t)
```

You are also able to include Laplace transforms and inverse Laplace transforms in the usual evaluation loop.
To do this, simply encapsulate the expression you want to take the Laplace transform or inverse Laplace transform of in `\mathcal{L}(...)` or `\mathcal^{-1}(...)` respectively, visually select it and run the `:TungstenEvaluate` command.

**Example**:
```latex
  \mathcal{L}^{-1} \left( \frac{1}{s} \right) = 1
  \mathcal{L} \left( t^{n} \right) = s^{-n-1} \Gamma (n+1)
  \mathcal{L}(\delta(t-a)) \cdot \mathcal{L}\left( u(t-a) \right) = \frac{u (a) e^{-a s} \left(e^{-a s} u (a)+u (-a)\right)}{s}
```


## Wronskians

You can calculate the Wronskian determinant of a set of functions using the `:TungstenWronskian` command. The syntax expects the functions to be wrapped in `W(...)` and separated by commas.

**Example**:
```latex
  W(y_1, y_2) \rightarrow y_1(x) y_2'(x)-y_2(x) y_1'(x)
  W(f, g, h) \rightarrow h'(x) \left(g(x) f''(x)-f(x) g''(x)\right)+h''(x) \left(f(x) g'(x)-g(x) f'(x)\right)+h(x) \left(f'(x) g''(x)-f''(x) g'(x)\right)
```

## Convolutions

Tungsten supports calculating the finite convolution of two functions, commonly used in Differential Equations and Laplace transforms. The syntax uses the \ast operator (rendered as an asterisk or star) between two functions.

The mathematical definition of this is
```math
  (f \ast g)(t) = \int_{0}^{t} f(\tau) g(t - \tau) \mathrm{d}\tau
```

You can execute a convolution either throug the `:TungstenEvaluate` or the `:TungstenConvolve` commands.

**Example**:
```latex
  t \ast e^{t} = -t+e^t-1
  \sin(t) \ast \cos(t) = \frac{1}{2} t \sin (t)
```

*Note*: The convolution handler assumes the independent variable is t. If you use other variables, the backend may default to a generic infinite convolution or fail to evaluate.
