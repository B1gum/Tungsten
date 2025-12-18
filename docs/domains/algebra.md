# Arithmetic and Algebra

Tungsten provides all of the basic mathematical operations through its arithmetic and algebra domain.
Tungsten works on LaTeX-formatted input.
This is showcased underneath, where the LaTeX-formatted expressions on the left have been evaluated using the `:TungstenEvaluate` command.

```latex
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
  - Inequality relations i.e. `<`, `>`, `\le`, `\leq`, `\ge`, and `\geg`, as well as the forms `<=`, `>=`, `≤`, and `≥`.

To evaluate an expression simply select the expression using visual mode and run the `:TungstenEvaluate` command. 
When the backend has evaluated the expression the result is inserted on the right hand side of your visual selection preceded by a `=`.
I.e. if you visually select `2 + 2` in the buffer and run `:TungstenEvaluate`, the buffer will, upon completion of the evaluation show `2 + 2 = 4`.

The default mapping for the `:TungstenEvaluate` command is `<leader>tee`

The default mapping in Vim/Neovim for entering visual mode is pressing `v` in normal mode. One could also opt to highlight ones expression using the cursor. 


## Defining and Managing Persistent Variables

Tungsten supports *persistent variables*, meaning you can assign a value to a variable or symbol once and then reuse it in later evaluations.
This is useful when working through a derivation in LaTeX, where you want to keep intermediate results around without having to rewrite them lots of times.

Variables are stored in Tungsten's session state (i.e. they persist across command calls until you clear or overwrite them)

### Defining a Variable

Tungsten uses `:=` as the default assignment operator (see [configuration](reference/config) to change the default).
Say that we want to e.g. assign the numerical value `2` to a variable `a`, we simply visually select
```latex
a := 2
```
and run the `:TungstenDefinePersistentVariable` command (the default mapping is `<leader>ted`). After having done this Tungsten will understand that any time we write `a` we are actually writing `2`.
In this way, we are able to use the variable in subsequent evaluations, e.g.
```latex
a \cdot 2 = 4
```
You can also define variables that depend on other variables.
```latex
b := \frac{a}{2}
```
And then use these in calculations:
```latex
b + 3 = 4
```
or simply check their value by using `:TungstenEvaluate` with an input of just the variable as:
```latex
b = 1
```

You are also able to evaluate an expression and assign the evaluated value to a variable in one go. To do this, simply type the variable, followed by its definition, just as you would when normally definining a variable but then instead of using `:TungstenDefinePersistentVariable` use `:TungstenEvaluate`. This gives:
```latex
c := \frac{4}{2} = 2
c - 2 = 0
```

To clear all defined persistent variables use the `:TungstenClearPersistentVars` command.


## Solving Equations

Tungsten also offers equation solving capabilities. For a simple equation of one variable such as `x + 3 = 1` you can solve the equation for the variable `x` by visually selecting the equation and executing the `:TungstenSolve` command. After entering the command, an input window pops up with the prompt `Enter variable to solve for (e.g., x)`. In this prompt you simply type the variable, in this case `x` and hit enter.
Doing this, Tungsten outputs
```latex
x + 3 = 1 \rightarrow x = -2
```

You can also solve a more general algebraic equation containing multiple variables for one of these, e.g. inputting `x^2 + y^2 = 1` and solving for `y` tungsten outputs
```latex
x^2 + y^2 = 1 \rightarrow y = \sqrt(1 - x^2)
```


## Solving Systems of equations

It is also possible to solve systems of equations.
To do this, write a series of expressions, separated by either `\\` or `;` e.g.
```latex
x^2 + y^2 &= 4 \\
x^2 - 2y^2 &= -2
```
or
```latex
x^2 + y^2 = 4;
x^2 - 2y^2 = -2
```
and enter the `:TungstenSolveSystem` command. After entering the command, a prompt pops up asking you which variables to solve for. Tungsten expects you to enter as many variables as you have entered equations. On the above example one would enter `x, y` or `x; y` (both are equivalent) and hit enter after which Tungsten solves the system of equations ans outputs:
```latex
x^2 + y^2 &= 4 \\
x^2 - 2y^2 &= -2 \rightarrow \left\{\left\{x\to -\sqrt{2},y\to -\sqrt{2}\right\},\left\{x\to -\sqrt{2},y\to \sqrt{2}\right\},\left\{x\to \sqrt{2},y\to -\sqrt{2}\right\},\left\{x\to \sqrt{2},y\to \sqrt{2}\right\}\right\}

x^2 + y^2 = 4;
x^2 - 2y^2 = -2 \rightarrow \left\{\left\{x\to -\sqrt{2},y\to -\sqrt{2}\right\},\left\{x\to -\sqrt{2},y\to \sqrt{2}\right\},\left\{x\to \sqrt{2},y\to -\sqrt{2}\right\},\left\{x\to \sqrt{2},y\to \sqrt{2}\right\}\right\}
```
Note that `&=` is parsed by Tungsten as `=` and you can therefore easily solve systems of equations in `align`-blocks.



## Simplifying Expressions

Simplifying takes an expression and rewrites into an equivalent form that is usually shorter or cleaner in some fashion.
Since this is not a well-defined mathematical concept the backends may return different but equivalent froms depending on settings.

To simplify an expression just select the expression in insert mode and run the `:TungstenSimplify` command. When the evaluation is complete the result will be inserted as `<Expression> \rightarrow <Simplification>`. This is shown underneath.

**Example:**
```latex
\frac{x^2 - 1}{x-1} \rightarrow x + 1
```

**Example:**
```latex
\frac{2x^2 + 4x}{2x} \rightarrow x + 2
```

The standard keymapping for the `:TungstenSimplify` command is `<leader>tes`.

## Factoring expressions

To factor an expression using Tungsten, visually select it and run the `:TungstenFactor` command.
When the backend has finidhsed, Tungsten inserts the factored result as `<Expression> \righarrow <FactoredRes>`.
This is shown underneath.

**Example**
```latex
x^2 - 1 \rightarrow (x-1) (x+1)
x^2 + 4x + 4 \rightarrow (x + 2)^2
```

The standard keymapping for the `:TungstenFactor` command is `<leader>tef`


## Constants known to Tungsten

A few commonly used constants are known to Tungsten. The list of known constants will be expanded and opportunities for adding new constants and ignoring known ones will be added at a later time.
Currently Tungsten knows:
  - `e`, Euler's constant (≈2,718)
  - `π`, Pi (≈3,141)
  - `∞`, Infinity
