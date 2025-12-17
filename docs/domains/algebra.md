# Arithmetic and Algebra

Tungsten provides all of the basic mathematical operations through its arithmetic and algebra domain.
Tungsten works on LaTeX-formatted input.
This is showcased underneath, where the LaTeX-formatted expressions on the left have been evaluated using the `:TungstenEvaluate` command.

```
2 + 2 \cdot 2 = 6

8 - 3 = 5

\frac{8}{2} \cdot 1.5 = 6

\sqrt{2^{2+2}} =  4

\sin{\pi} = 0
```


## Evaluating Expressions

The arithmetic and algebra domain adds support for:

  - Addition and subtraction using `+` and `-` respectively.
  - Multiplication using `\cdot` and `\times` (for vector inputs these have different meanings, see [Linear Algebra](docs/domains/linear-algebra))
  - Division using `\frac{}{}`. 
  - Exponents using `^{}`
  - The natural and base 10 logarithms, using `ln` and `log` respectively.
  - Roots, using `\sqrt[a]{b}` (corresponding to the `a`'th root of `b`)
  - The trig functions `\sin`, `\cos`, `\tan`, `\cot`, `\sec`, `\csc`, and the hyperbolic forms `\sinh`, `\cosh`, `\tanh`. The inverse trig functions are implemented via `\sin^{-1}` syntax.

To evaluate an expression simply select the expression using visual mode and run the `:TungstenEvaluate` command. 
When the backend has evaluated the expression the result is inserted on the right hand side of your visual selection preceded by a `=`.
I.e. if you visually select `2 + 2` in the buffer and run `:TungstenEvaluate`, the buffer will, upon completion of the evaluation show `2 + 2 = 4`.

The default mapping for the `:TungstenEvaluate` command is `tee`

The default mapping in Vim/Neovim for entering visual mode is pressing `v` in normal mode. One could also opt to highlight ones expression using the cursor. 


## Defining and Managing Persistent Variables

Tungsten supports *persistent variables*, meaning you can assign a value to a variable or symbol once and then reuse it in later evaluations.
This is useful when working through a derivation in LaTeX, where you want to keep intermediate results around without having to rewrite them lots of times.

Variables are stored in Tungsten's session state (i.e. they persist across command calls until you clear or overwrite them)

### Defining a Variable
To define a variable, visually select an assignment *FIX BEFORE*

## Solving Equations


## Solving Systems of equations


## Simplifying Expressions

Simplifying takes an expression and rewrites into an equivalent form that is usually shorter or cleaner in some fashion.
Since this is not a well-defined mathematical concept the backends may return different but equivalent froms depending on settings.

To simplify an expression just select the expression in insert mode and run the `:TungstenSimplify` command. When the evaluation is complete the result will be inserted as `<Expression> \rightarrow <Simplification>`. This is shown underneath.

**Example:**
```
\frac{x^2 - 1}{x-1} \rightarrow x + 1
```

**Example:**
```
\frac{2x^2 + 4x}{2x} \rightarrow x + 2
```

## Factoring Expressions


## Constants known to Tungsten
core/constants.lua



  - Inequality relations i.e. `<`, `>`, `\le`, `\leq`, `\ge`, and `\geg`, as well as the forms `<=`, `>=`, `≤`, and `≥`.

