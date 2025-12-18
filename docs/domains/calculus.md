# Calculus

Tungsten supports core calculus operations throught its calculus domain. This includes support for limits, dertivatives, integrals, and summations, all of which can be evaluated directly from the LaTeX-formatted input using `:TungstenEvaluate`.

```latex
\lim_{x \to 0} \frac{\sin x}{x} = 1
\frac{\mathrm{d}}{\mathrm{d}x} x^2 = 2 x
\int_{0}^{1} x^2 \, \mathrm{d}x  = \frac{1}{3}
\sum_{i = 1}^{n} i  = \frac{1}{2} n (n+1)
```


## Derivatives

The calculus domain provides support for both partial derivatives and ordinary derivatives formatted according to either the Leibniz, Lagrange or Newton notation.

### Leibniz Notation

Derivatives written in Leibniz notation can be readily parsed by Tungsten.
When writing Leibniz-style derivatives one can either choose to write the `d`'s upright as
```latex
  \frac{\mathrm{d}}{\mathrm{d}x} x^2 + 2 = 2x + 2
```
or as slanted `d`'s as
```latex
  \frac{d}{dx} x^2 + 2x = 2x + 2
```

Tungsten will greedily capture the expression after the `\frac{d}{dx}`-block, meaning `2x` is also differentiated in the above example.
If one wants to delimit the derivative this can be done either using parentheses or by placing the expression you want to find the derivative of in the numerator as
```latex
  \frac{\mathrm{d}}{\mathrm{d}x} \left( x^2 \right) + 2x = 4x
  \frac{\mathrm{d}x^2}{\mathrm{d}x} + 2x = 4x
```

### Lagrange Notation

Lagrange notation is supported in both infix and postfix forms

**Infix Notation**:
This is used for function calls like `f'(x)`.
Tungsten captures the function identifier (e.g., `f`), the number of prime symbols (`'`) to determine derivative order, and the argument (e.g., `x`).

**Postfix Notation**:
This is used for simple variables like `y''`.
If no explicit argument is provided, the system defaults to using `x` as the variable of differentiation.


Lagrange notation is especially useful in Tungsten when working with [differential equations](docs/domains/differential-equations).


### Newton Notation

Newton notation (dot notation) is implemented using the standard LaTeX-commands `\dot{f}` and `\ddot{f]` corresponding to the first and second derivative of `f` respectively. 
Newton notation typically implies a deriviative with respect to time, and the system will therefore automatically assign `t` as the variable of differentiation for these nodes.

Newton notation is especially useful in Tungsten when working with [differential equations](docs/domains/differential-equations).


### Partial Derivatives

Tungsten is also able to parse partial derivatives using a syntax like
```latex
  \frac{\partial}{\partial x} x^2 \cdot y^2 = 2 x y^2
  \frac{\partial^2}{\partial x \partial y} x^2 \cdot y^2  = 4 x y
  \frac{\partial^2}{\partial x^2} x^2 \cdot y^2 = 2 y^2
```
As can be seen above, it is possible to both find single and multiple derivatives of one or more variables.

Partial derivatives follow the same capturing logic as ordinary derivatives. I.e. Tungsten will, by greedily capture the expression after the partial derivative.

If one wants to delimit the derivative this can be done either using parentheses or by placing the expression you want to find the derivative of in the numerator as
```latex
  \frac{\partial}{\partial x} (x^2) + y^2 = 2 x+y^2
  \frac{\partial x^2}{\partial x} + y^2 = 2 x+y^2
```


## Integrals

Tungsten readily parses both indefinite and definite integrals.

### Indefinite Integrals

The least required syntax for Tungsten to parse an integral is:
```latex
  \int <Expression> d<Variable>
```
where `<Expression>` (`2x`underneath) is the expression to be integrated and `<Variable>` (`x` underneath) the variable of integration.

**Example**:
```latex
  \int 2x dx = x^2
```

You can also choose to write the `d` upright and with either `\,`, `\.` or `\;` as spacing. I.e.
**Example**:
```latex
  \int 2x \, \mathrm{d}x = x^2
  \int 2x \. \mathrm{d}x = x^2
  \int 2x \; \mathrm{d}x = x^2
```


### Definite Integrals

Definite integrals follow the same rules as indefinite integrals, however here a lower and upper bound is also given as
```latex
  \int_{0}^{1} 2x \, \mathrm{d}x  = 1
  \int_{-\pi}^{\pi} \cos \left( \frac{2y}{\pi} \right) \, \mathrm{d}y = \pi  \sin (2)
```


## Limits and Summations

Tungsten is also able to handle limits and sums. These follow the standard LaTeX-syntax of
```latex
  \lim_{<Variable> \to <Point>} <Expression>
```
and
```latex
  \sum_{<Variable> = <Start>}^{<End>} <Expression>
```

**Example**:
```latex
  \lim_{x \to 0} \frac{\sin x}{x}
  \lim_{y \to \infty} \frac{1}{x}
  \sum_{i = 1}^{n} i = \frac{1}{2} n (n+1)
  \sum_{k = 1}^{\infty} \frac{1}{k^2} = \frac{\pi^2}{6}
```
