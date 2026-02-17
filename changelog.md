## [0.1.0] - 2026-01-16

### Features

- Initial release of Tungsten with Wolfram Engine integration and plotting features

### Fixed

- A bug where multiple parenthesised expressions after one another led to the parser believing a chained relation was entered
- Added a rockspec and documented luarocks dependencies


## [0.1.1] - 2026-01-30

### Fixed

- Added `luafilesystem` and `penlight` to rockspec

## [0.2.0]

### Features

- Added persistent sessions for the wolfram backend (on by default, can be toggled using `:TungstenTogglePersistence`)
- Implemented the Python backend for computation and plotting
- Implemented the `:TungstenSwitchBackend` command allowing the user to switch the backend post-setup
- Added parsing rules for `\prod` akin to those already implemented for `\sum`
- Added parsing rules for `\binom` meaning both backends are able to evaluate binomials
- Added support for factorial notation using `!` (e.g. `n!`)

### Fixed

- Added `luafilesystem` and `penlight` to rockspec
- Added `scripts/install_python_deps.sh` and run it at build-time to automatically install python dependencies
- Corrected timout error-reporting
- Made persistent sessiosn respect timeouts
- Removed luarocks dependencies

### documentation

- Updated documentation index to include all the relevant information from the README ontop of the previous content
- Updated documentation to mention `telescope` and `which-key` as optional dependencies
- Added coverage reporting to readme
- Added contributor documentation including `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`, `SUPPORT.md` and `STYLE.md`
- Updated the Capability Matrix and configuration guides to reflect that the Python backend is now fully supported for evaluation and plotting.
