# Units

Tungsten supports quantities with units, angles and formatted numbers through its `units` domain.
This domain is designes to be compatible with the syntax of the LaTeX package `siunitx`.

This allows for the evaluation of expressions involving units directly from your LaTeX input.

**Example**:
```latex
\qty{10}{\km} + \qty{500}{\m} + \qty{5}{\cm} = \qty{10.50005}{Kilometers}

\ang{90} + \ang{45} = \ang{135}

\qty{5}{\m\per\s} \cdot \qty{10}{\s}  = \qty{50}{\meter}
```

## Quantities

The primary way to define a value with a unit is using the `\qty` command.
The syntax follows the pattern `\qty{<number>}{<unit>}`.
The numeric portion supports scientific notation via `e` and either `.` or `,` as decimal separators.

**Example**:
```latex
\qty{5}{\kg}
\qty{9.81}{\m\per\s\squared}
\qty{2,8e3}{\Pa}
```

### Unit Syntax

Tungsten's parser supports a robust set of operations for defining complex units within the second argument of the `\qty` command.

**Multiplication**
Units can be multiplied using several separators:
  - Interword space or `.` (dot)
  - `*` (asterisk)
  - `\cdot`

**Division**
Units can be divided using:
  - `/` (slash)
  - `\per`

**Exponents and Modifiers**
Powers cna be applied to units using the standard `^` (caret) syntax or through the `siunitx`-specific helper macros.
  - Explicit exponents: `\m^2`, `\s^{-1}`.
  - Postfix helper macros: `\m\squared`, `\m\cubed`.
  - Prefix helper macros: `\square\m`, `\cube\m`.

**Example**:
```latex
\qty{100}{\newton\cdot\meter} = \qty{100}{\joule}

\qty{9.8}{\meter\per\second\squared}  = \qty{9.8}{\meter\per\second^2}

\qty{1000}{\kg.\m^{-3}} = \qty{1000}{\kilogram\per\meter^3}
```

*Note*: You can use both the LaTeX-macros (e.g. `\m`, `\kg`) and literals (e.g. `m`, `kg`) for unit components.

## Angles

The `units` domain provides support for angles given in angular degrees using the `\ang{<degrees>}` syntax.

**Example**:
```latex
\ang{180} + \ang{25}  = \ang{205}
```

## Formatted Numbers

For consistency with `siunitx`, Tungsten also supports the `\num` command.
While primarily used for formatting in LaTeX, Tungsten will automatically understand numbers formatted through either the `\num{<PreExponent>e<Exponent>}` or using either `.` (dot) or `,` (comma) as decimal separators.
I.e. all of the following are valid Tungsten constructs:

```latex
\num{7e8} = 700000000
\num{2e-2} = 0.02
\num{2,2} = 2.2
\num{3.7} = 3.7
```
