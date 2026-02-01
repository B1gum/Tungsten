## [0.1.0] - 2026-01-16

### Features

- Initial release of Tungsten with Wolfram Engine integration and plotting features.

### Fixed

- A bug where multiple parenthesised expressions after one another led to the parser believing a chained relation was entered
- Added a rockspec and documented luarocks dependencies


## [0.1.1] - 2026-01-30

### Features

- Added persistent sessions (on by default, can be toggled using `:TungstenTogglePersistence`)
- Implemented the Python backend for computation (everything except plotting)
- Implemented the `:TungstenSwitchBackend` command allowing the user to switch the backend post-setup

### Fixed

- Added `luafilesystem` and `penlight` to rockspec
- Added `scripts/install_python_deps.sh` and run it at build-time to automatically install python dependencies

### documentation

- Updated documentation index to include all the relevant information from the README ontop of the previous content
- Updated documentation to mention `telescope` and `which-key` as optional dependencies
- Added coverage reporting to readme
- Added contributor documentation including `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`, `SUPPORT.md` and `STYLE.md`
