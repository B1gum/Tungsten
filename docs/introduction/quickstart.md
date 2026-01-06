# Quickstart
This guide will get you your first result with Tungsten immediately after installation.

```text
Input:  1 + 1
Action: <leader>tee  (Visual Select + Leader + t + e + e)
Output: 1 + 1 = 2
```

## Step-by-Step

### 1. Open a Scratch File
Open a new file in Neovim to test the plugin.
```bash
nvim test.tex
```

### 2. Basic Evaluation
Type a simple arithmetic expression into the buffer:
```latex
1 + 1
```
Enter Visual Mode by pressing `v` and select the text `1 + 1`.
Then, trigger the `:TungstenEvaluate` command (the default keybinding is `<leader>tee`).

### 3. See the Result
Tungsten will process the expression and insert the result directly into your buffer.
By defult, it uses `=` as a separator.
```latex
1 + 1 = 2
```

### 4. Persistent Variables
You can define variables that persist across different evaluations.
E.g. try to type the following assignment (using `:=` as the default assignment operator):
```latex
x := 5
```
Now, select the text `x := 5` and run the `:TungstenDefinePersistentVariable` command (`<leader>ted`).
This will store the value of `x = 5` in the current session.

Now, we can use that variable in a new expression, such as:
```latex
x \cdot 2
```
Selecting `x \cdot 2` and running `:TungstenEvaluate` we obtain:
```latex
x \cdot 2 = 10
```

### See Also
  - For a more in-depth walk-through of the mathematical capabilities see the individual [Domain pages](/docs/domains/index.md).
  - To see all available commands see [Commands](/docs/reference/commands.md).
  - For configuration and setup-options see [Configuration](docs/reference/config.md).
