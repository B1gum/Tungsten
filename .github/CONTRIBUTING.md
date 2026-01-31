# Contributing to Tungsten

Thanks for your interest in contributing! This guide explains how to report issues, propose changes, and prepare pull requests.

## Table of Contents
- [Code of Conduct](#code-of-conduct)
- [Ways to Contribute](#ways-to-contribute)
- [Reporting Issues](#reporting-issues)
- [Proposing Changes](#proposing-changes)
- [Development Setup](#development-setup)
- [Testing and Quality Checks](#testing-and-quality-checks)
- [Commit Messages](#commit-messages)
- [Pull Request Checklist](#pull-request-checklist)

## Code of Conduct
Please read and follow the [Code of Conduct](CODE_OF_CONDUCT.md) when participating in this project.

## Ways to Contribute
- Report bugs or regressions.
- Propose features or improvements.
- Improve documentation and examples.
- Add or refine tests.

## Reporting Issues
Before opening an issue, please:
1. Search existing issues to avoid duplicates.
2. Collect details (Neovim version, OS, Tungsten version, logs, and reproduction steps).

When opening an issue, include:
- **What happened** and **what you expected**.
- **Reproduction steps** with minimal configuration.
- **Logs or screenshots** where applicable.
- **Environment details** (OS, Neovim version, and dependencies).

## Proposing Changes
For significant changes (new domains, parser work, backend work), please:
1. Open an issue to discuss the idea.
2. Align on scope and approach.
3. Implement the change in a focused PR.


## Development Setup
Tungsten uses Lua and depends on Neovim. The development workflow relies on `luarocks` for dependencies.

1. Install prerequisites:
   - Neovim (stable or nightly)
   - Lua + Luarocks
   - Wolfram Engine + WolframScript (see [Installation Guide](docs/introduction/installation.md))
2. Clone the repository:
   - `git clone https://github.com/B1gum/Tungsten.git`
   - `cd Tungsten`
3. Install dependencies for tests and linting:
   - `make deps`

## Testing and Quality Checks
Run the full suite:
- `make all`

Individual checks:
- **Tests**: `make test`
- **Lint**: `make lint`
- **Formatting**: `make fmt` (auto-format), `make fmt-check` (check only)

Please ensure all checks pass before submitting a PR.

## Commit Messages
Follow a clear, consistent format so history stays readable. Recommended format:

- `type: summary`

Examples:
- `docs: add contribution guide`
- `fix: handle empty input`
- `feat: support multiple series`

Types we use most often: `feat`, `fix`, `docs`, `chore`, `refactor`, `test`.

## Pull Request Checklist
- [ ] Linked issue or context provided.
- [ ] Tests and linting pass locally (`make all`).
- [ ] Documentation updated (if applicable).
- [ ] Clear description of what changed and why.
- [ ] Screenshots or recordings for UI/UX changes.

## Documentation Style
See [STYLE.md](STYLE.md) for formatting conventions.

