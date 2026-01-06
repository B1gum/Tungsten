# Numerics

By default, Tungsten prioritizes symbolic evaluation, meaning that expressions like `\sqrt{2}` or `\pi` are kept in their exact forms.
However, Tungsten also supports numeric evaluation, allowing you to compute decimal approximations of expressions.

This is showcased underneath, where the expressions on the left have been evaluated using the `:TungstenEvaluate` command.

**Symbolic Evaluation (Default)**:
```latex
\sqrt{2} = \sqrt{2}

\pi = \pi

\sin(1) = \sin (1)
```

**Numeric Evaluation**:
```latex
\sqrt{2} = 1.41421

\pi = 3.14159

\sin(1) = 0.841471
```

## Toggling Numeric Mode

You can toggle between symbolic and numeric evaluation modes using the `:TungstenToggleNumericMode` command.
After running the command an info-message appears saying either `Numeric mode enabled.` or `Numeric mode disabled.` depending on the current state.
When numeric mode is enables, Tungsten will attempt to resolve all evaluations to a numerical alue.

The default keymapping for the `:TungstenToggleNumericMode` command is `<leader>ttn`.
