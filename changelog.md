## [Unreleased]

## [0.3.0] - 2026-10-09

### Features

- Add support for absolute values using `|...|`, `\left| ... \right|`, and related notation.
- Add the `:checkhealth Tungsten` command.
- Add `:TungstenCollect` to collect expressions by powers of a selected variable, with Wolfram and Python support.
- Support expanded products, simplified coefficients, subscripted variables, and numeric mode in the Python implementation of `:TungstenCollect`.
- Add a visual-mode `<leader>tec` mapping for `:TungstenCollect` when default mappings are enabled.
- Support session-local function definitions such as `f(x) = x^2` and subsequent evaluation of calls such as `f(5)` on both backends.
- Add the `symbolic_functions` configuration option to control which undefined names are interpreted as symbolic functions.
- Add support for modified Bessel functions using uppercase `I_{<order>}(<argument>)` and `K_{<order>}(<argument>)` notation.

### Fixed

- Add support for negative values in `\num{}`.
- Pass configuration options to persistent Wolfram sessions.
- Validate Tungsten user configuration during setup.
- Distinguish function calls from implicit multiplication so that expressions such as `x(x + 1)` are interpreted as multiplication unless `x` is a known function.
- Support Greek and subscripted variables as targets in Solve and SolveSystem commands.
- Preserve `\theta` and subscripted theta symbols in Wolfram output.
- Correct parsing of hyperbolic trigonometric functions.
- Correct handling of units beginning with `\per`.
- Normalize persistent unit output and reload backend handlers when switching backends.
- Insert a valid LaTeX `\rightarrow` separator for `:TungstenCollect`.
- Register Wolfram's `Evaluate` mapping used when ordering collected terms.
- Clear session-local function definitions and cached results when running `:TungstenClearPersistentVars`.

### Documentation

- Document `:TungstenCollect` in the command reference and describe both backends in the algebra guide.
- Document function definitions, implicit multiplication, symbolic function configuration, and current function-definition limitations.
- Update syntax and differential-equation documentation to clarify function-call handling.

### Maintenance

- Isolate Lua test dependencies within the project.
- Improve test isolation and expand regression coverage for parsing, function evaluation, Collect, solving, and backend formatting.
- Replace a deprecated Neovim list API.

### Known Issues

- Wolfram Solve and SolveSystem may intermittently fail with a license-related startup message when persistence is enabled, including on an activated installation. Disabling persistence with `:TungstenTogglePersistence` has worked around the reported issue. The underlying cause has not yet been confirmed.

### Contributors

- Thanks to @skorobogatov-mipt for contributing Collect and fixes for Greek solve targets and Wolfram theta output.


## [0.2.0] - 2026-02-21

### Features

- Add persistent sessions for the Wolfram backend, enabled by default and toggleable using `:TungstenTogglePersistence`.
- Implement the Python backend for computation and plotting.
- Implement `:TungstenSwitchBackend` to switch backends after setup.
- Add parsing rules for `\prod`, matching the existing support for `\sum`.
- Add support for `\binom` on both backends.
- Add support for factorial notation using `!`, such as `n!`.
- Add support for siunitx-formatted units and numbers using `\qty{}{}`, `\ang{}`, and `\num{}`.
- Extend the plotting job spinner to all evaluations.

### Fixed

- Add `scripts/install_python_deps.sh` and run it at build time to install Python dependencies automatically.
- Correct timeout error reporting.
- Make persistent sessions respect timeouts.
- Remove LuaRocks dependencies.

### Documentation

- Expand the documentation index to include the relevant README content.
- Document `telescope` and `which-key` as optional dependencies.
- Add coverage reporting to the README.
- Add contributor documentation, including `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`, `SUPPORT.md`, and `STYLE.md`.
- Update the capability matrix and configuration guides to reflect Python support for evaluation and plotting.

## [0.1.1] - 2026-01-30

### Fixed

- Add `luafilesystem` and `penlight` to the rockspec.

## [0.1.0] - 2026-01-16

### Features

- Initial release of Tungsten with Wolfram Engine integration and plotting features.

### Fixed

- Correct parsing of consecutive parenthesized expressions incorrectly interpreted as a chained relation.
- Add a rockspec and document LuaRocks dependencies.
