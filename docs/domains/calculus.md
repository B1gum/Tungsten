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

Tungsten will, by greedily capture the expression after the `\frac{d}{dx}`-block, meaning `2x` is also differentiated in the above example.
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

## Integrals

### Indefinite Integrals

### Definite Integrals

## Limits and Summations


