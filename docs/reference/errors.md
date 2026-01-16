# Troubleshooting & Errors

This guide provides solutions for common runtime errors encountered when using Tungsten. It covers generic UI errors, backend-specific issues, and instructions for enabling debug logging.

## Common Issues

### Backend Availability

**Symptom**: `Tungsten[Executor] E_BACKEND_UNAVAILABLE`

**Cause**: The plugin cannot locate the configured backend executable (e.g., `wolframscript`). This usually means the executable is not in your system's `$PATH` or the path specified in the configuration is incorrect.

**Solution**:
  1. Verify that the backend is installed and accessible from your terminal.
  1. Check your Tungsten configuration (`backend_opts`). Ensure `wolfram_path` (default: "wolframscript") points to a valid executable.

### Timeouts

**Symptom**: `Tungsten[Executor] E_TIMEOUT`

**Cause**: The calculation or plotting job took longer than the configured time limit. The default timeout is 30,000ms (30 seconds).

**Solution**: Increase the `process_timeout_ms` option in your `setup({})` configuration:

```lua
require("tungsten").setup({
    process_timeout_ms = 60000, -- Increase to 60 seconds
})
```

### Plotting / LaTeX errors

**Symptom**: `Tungsten[Plotting] E_TEX_ROOT_NOT_FOUND`

**Cause**: Tungsten could not locate the root file of your project. Include a `#!TEX ROOT = <main.tex>` magic-comment in your file. (See [Plotting](domains/plotting.md))


### Syntax & Backend Errors

**Symptom**: Specific error messages from the backend, such as `Syntax::sntx` (Wolfram).

**Cause**: The code sent to the backend contained invalid syntax or triggered a runtime exception.

**Solution**: Check the syntax of the selected code. If you believe Tungsten should be able to understand your expression, but is not please file a [Bug report](https://github.com/B1gum/Tungsten/issues).

You may also encounter `E_BACKEND_CRASH`, if the backend process exits unexpectedly.

### Plotting-Specific Errors

The following error codes may only appear when plotting:


  - `E_UNSUPPORTED_DIM`: The requested plot dimension is not supported. This typically happens if you try to plot too many variables (i.e. 3 or more variables in a 2D plot or 4 or more in a 3D plot.)
  - `E_NO_PLOTTABLE_SERIES`: The expression did not result in data that can be plotted.
  - `E_MIXED_COORD_SYS`: Attempted to combine incompatible coordinate systems in one plot (e.g., polar and cartesian coordinates in the same plot). 

## Logging

If you encounter issues not listed above, you can enable debug logging to inspect the raw communications between Tungsten and the backend.

### Enabling Debug Logs

Modify your configuration to lower the log level:
```latex
require("tungsten").setup({
    log_level = "DEBUG", -- Default is "INFO"
    debug = true,
})
```

### Viewing Logs

Tungsten uses the standard Neovim notification system (`vim.notify`). 
You can view the log history using the `:messages` command in Neovim.
