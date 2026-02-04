# Configuration

Tungsten is highly configurable, allowing you to tailor the backend, plotting behavior, and keybindings to your workflow. This guide details all available configuration options.

## Complete Configuration

The following snippet demonstrates a comprehensive setup using `lazy.nvim` or a standard `init.lua`. It highlights common overrides, such as setting the backend path and customizing plotting options.

```lua
require("tungsten").setup({
    -- Core Behavior
    backend = "wolfram", -- Default backend, "wolfram" or "python"
    numeric_mode = false, -- If true, returns decimal approximations by default
    debug = false, -- Enable debug logging
    log_level = "INFO", -- Options: "DEBUG", "INFO", "WARN", "ERROR"
    
    -- Cache Settings
    cache_enabled = true,
    cache_max_entries = 100,
    cache_ttl = 3600, -- Time to live in seconds
    
    -- Execution Settings
    process_timeout_ms = 30000,
    max_jobs = 3, -- Max concurrent async jobs
    job_spinner = true, -- Show a spinner during evaluation jobs
    
    -- UI & Formatting
    result_separator = " = ",
    result_display = "insert", -- Options: "insert", "float", "virtual"
    persistent_variable_assignment_operator = ":=",
    enable_default_mappings = true,
    
    -- Backend Specific Configuration
    backend_opts = {
        wolfram = {
            persistent = true, -- If true, keeps the backend engine running between calculations (faster)
            wolfram_path = "wolframscript", -- Path to the executable
            -- Custom function name mappings
            function_mappings = {
                sin = "Sin",
                log = "Log",
                -- ... add others as needed
            },
        },
    },

    -- Plotting Configuration
    plotting = {
        backend = "wolfram",
        usetex = true, -- Use LaTeX for label rendering
        latex_engine = "pdflatex",
        outputmode = "latex", -- Options: "latex", "image"
        filename_mode = "sequential",
        viewer_cmd_pdf = "open", -- Command to open PDF plots
        viewer_cmd_png = "open", -- Command to open PNG plots
        snippet_width = "0.8\\linewidth", -- LaTeX width in document
        
        -- Default Ranges
        default_xrange = { -10, 10 },
        default_yrange = { -10, 10 },
        default_zrange = { -10, 10 },
        default_theta_range = { 0, "2*Pi" },
    },
    
    -- Available Domains
    domains = { 
        "arithmetic", 
        "calculus", 
        "linear_algebra", 
        "differential_equations", 
        "plotting", 
        "units" 
    },
    
    -- Event Hooks
    hooks = {},
})
```

## Option Reference

The configuration is broadly divided into general settings, backend options, and plotting configuration.

### General Options

| Option | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `backend` | string | `"wolfram"` | The mathematical engine to use. Currently supports `"wolfram"` and `python` |
| `numeric_mode` | boolean | `false` | If true, results are computed numerically (e.g., `1.414`) instead of symbolically (e.g., `sqrt(2)`). |
| `debug` | boolean | `true` | Enables extended debug information. |
| `log_level` | string | `"INFO"` | Sets the verbosity of the logger. (`"DEBUG"`, `"INFO"`, `"WARN"`, `"ERROR"`) |
| `process_timeout_ms` | number | `30000` | Maximum duration (ms) for a backend process before it times out. |
| `max_jobs` | number | `3` | Maximum number of concurrent backend jobs allowed. |
| `job_spinner` | boolean | `true` | If true, shows a spinner while evaluation jobs are running. |
| `result_separator` | string | `" = "` | The string inserted between the input expression and the result. |
| `result_display` | string | `"insert"` | How results are shown. `"insert"` appends to buffer. `"virtual"` displays it as virtual text and `"float"` displays the result in a floating window. |
| `persistent_variable_assignment_operator` | string | `":="` | Operator used to define variables that persist across evaluations. |
| `enable_default_mappings` | boolean | `true` | If true, registers the default `<leader>t` keybindings. |

### Backend Options (`backend_opts`)

This table allows configuration specific to the chosen `backend`.

**Wolfram Configuration (`backend_opts.wolfram`)**

| Key | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `wolfram_path` | string | `"wolframscript"` | The system executable path for the Wolfram engine. |
| `function_mappings` | table | `{...}` | Map internal function names (e.g., `sin`) to backend-specific names (e.g., `Sin`). |
| `persistent` | boolean | `true` | Keeps the backend engine running between calculations (faster). |


### Plotting Configuration (`plotting`)

Controls how graphs and plots are generated and displayed.

| Key | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `usetex` | boolean | `true` | If true, attempts to use LaTeX for rendering math labels in plots. |
| `latex_engine` | string | `"pdflatex"` | The LaTeX engine executable to use. |
| `outputmode` | string | `"latex"` | The output format preference. `"latex"` inserts the LaTeX-string, `"viewer"` opens the plot in an external viewer and `"both"` does both. |
| `viewer_cmd_pdf` | string | `"open"` | System command to view generated PDF files. Used for `outputmode="viewer"/"both"`. |
| `viewer_cmd_png` | string | `"open"` | System command to view generated PNG files. Used for `outputmode="viewer"/"both"`. |
| `default_xrange` | table | `{-10, 10}` | Default domain for the X-axis. |
| `default_yrange` | table | `{-10, 10}` | Default domain for the Y-axis. |
| `default_theta_range`| table | `{0, "2*Pi"}`| Default domain for polar plots. |

## Keymaps

If `enable_default_mappings` is set to `true`, Tungsten registers mappings using `which-key.nvim`. All mappings are prefixed with `<leader>t`.

| Key | Command | Description |
| :--- | :--- | :--- |
| **Evaluate** | | |
| `<leader>tee` | `TungstenEvaluate` | Evaluate the expression under cursor. |
| `<leader>ted` | `TungstenDefinePersistentVariable`| Define a persistent variable. |
| `<leader>tea` | `TungstenShowAST` | Show the Abstract Syntax Tree for debugging. |
| `<leader>tes` | `TungstenSimplify` | Simplify the expression. |
| `<leader>tef` | `TungstenFactor` | Factor the expression. |
| **Solve** | | |
| `<leader>tss` | `TungstenSolve` | Solve an equation for a variable. |
| `<leader>tsx` | `TungstenSolveSystem` | Solve a system of equations. |
| **Linear Algebra** | | |
| `<leader>tlg` | `TungstenGaussEliminate` | Perform Gauss-Jordan elimination. |
| `<leader>tli` | `TungstenLinearIndependent` | Test for linear independence. |
| `<leader>tlr` | `TungstenRank` | Calculate the rank of a matrix. |
| `<leader>tle...` | | Sub-menu for Eigenvalues/vectors. |
| **Differential Equations** | | |
| `<leader>tdo` | `TungstenSolveODE` | Solve an Ordinary Differential Equation. |
| `<leader>tdl` | `TungstenLaplace` | Compute the Laplace Transform. |
| `<leader>tdi` | `TungstenInverseLaplace` | Compute the Inverse Laplace Transform. |
| **Units** | | |
| `<leader>tuc` | `TungstenUnitConvert` | Convert a selected quantity or angle into another unit. |
| **System** | | |
| `<leader>tcc` | `TungstenClearCache` | Clear the internal result cache. |
| `<leader>ttn` | `TungstenToggleNumericMode` | Toggle between symbolic and numeric output. |
| `<leader>tm` | `TungstenPalette` | Open the Command Palette (Telescope). |

## See Also

  - [Installation](../introduction/installation.md) - Instructions for installing Tungsten and its dependencies.
  - [Commands](commands.md) – All commands defined by Tungsten.
  - [Domain Pages](../domains/index.md) – Domain-specific guides.
