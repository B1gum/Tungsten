# Configuration

To configure Tungsten, pass a table of options to the `setup` function in your `init.lua`.

### The Setup Function

```lua
require('tungsten').setup({
  -- Your custom configuration goes here
})
```

### Default Values
Below is the default configuration. You can copy and paste this into your setup function and modify the values as needed.
```latex
{
  numeric_mode = false,            -- If true, returns approximate numeric results (e.g., 1.414 instead of sqrt(2))
  debug = false,                    -- Enable debug logging
  log_level = "INFO",              -- Log level: "DEBUG", "INFO", "WARN", "ERROR"
  
  -- Cache Settings
  cache_enabled = true,            -- Enable caching of results to speed up repeated queries
  cache_max_entries = 100,         -- Maximum number of entries in the cache
  cache_ttl = 3600,                -- Time-to-live for cache entries in seconds
  
  enable_default_mappings = true,  -- Enable default keybindings
  
  -- Supported Math Domains
  domains = { "arithmetic", "calculus", "linear_algebra", "differential_equations", "plotting", "units" },
  
  process_timeout_ms = 30000,      -- Timeout for backend processes in milliseconds
  
  -- UI / Display Settings
  result_separator = " = ",        -- String separating the input expression from the result
  result_display = "insert",       -- How to show results: "insert", "virtual_text", or "float"
  
  max_jobs = 3,                    -- Maximum concurrent backend jobs
  
  persistent_variable_assignment_operator = ":=", -- Operator used for persistent variable assignment
  
  -- Backend Configuration
  backend = "wolfram",             -- Default backend: "wolfram" or "python" (under implementation)
  backend_opts = {
    wolfram = {
      wolfram_path = "wolframscript", -- Path to the wolframscript executable
      -- Internal function mappings for Wolfram
      function_mappings = {
        sin = "Sin", cos = "Cos", tan = "Tan", arcsin = "ArcSin", arccos = "ArcCos", 
        arctan = "ArcTan", sinh = "Sinh", cosh = "Cosh", tanh = "Tanh", arsinh = "ArcSinh", 
        arcosh = "ArcCosh", artanh = "ArcTanh", log = "Log", ln = "Log", log10 = "Log10", 
        exp = "Exp",
      },
    },
  },
  
  -- Plotting Configuration
  plotting = {
    backend = "wolfram",           -- Backend used specifically for plotting
    usetex = true,                 -- Use LaTeX for plot labels (requires functional LaTeX install)
    latex_engine = "pdflatex",     -- LaTeX engine to use
    latex_preamble = "",           -- Custom LaTeX preamble
    outputmode = "latex",          -- Plot output mode
    filename_mode = "sequential",  -- Naming strategy for generated plot files
    viewer_cmd_pdf = "open",       -- Command to open PDF plots
    viewer_cmd_png = "open",       -- Command to open PNG plots
    snippet_width = "0.8\\linewidth", -- Width of the plot in the generated document
    
    -- Default Ranges for plots
    default_xrange = { -10, 10 },
    default_yrange = { -10, 10 },
    default_zrange = { -10, 10 },
    default_t_range = { -10, 10 },
    default_theta_range = { 0, "2*Pi" },
    default_urange = { -10, 10 },
    default_vrange = { -10, 10 },
  },
}
```

### Key options
  - `backend`: Defines the computation engine used to solve expressions.
    - `"wolfram"` (default): Uses `wolframscript` and is currently the only fully-implemented backend.
    - `"python"`: Uses Python libraries (like SymPy/NumPy). This backend is currently being implemented and is not tested – It is therefore not advised to use this backend currently.
  - `result_display`: Controls how evaluation results are presented in the editor.
    - `"insert"` (default): Appends the result directly into the buffer (e.g., `1 + 1 = 2`).
    - `"virtual_text"`: Displays the result as virtual text next to the line (like a linter warning)
    - `"float"`: Displays the result in a floating window near the cursor.
  - `process_timeout_ms`: The maximum time (in milliseconds) the plugin will wait for the backend to return a result. The defualt is `30000` (30 seconds). Increase this if you frequently run very complex calculations that time out.

For a complete dictionary of every available option and advanced customization, see the [Configuration Reference](reference/config.md).
