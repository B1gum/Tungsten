# Style Guide

This document captures the conventions used in Tungsten.

## Formatting
- Use 2-space indentation (see `.stylua.toml`).
- Run `make fmt` before submitting changes.
- Use `make fmt-check` in CI or locally to verify formatting.

## Lua Code
- Follow the existing module layout under `lua/`.
- Use `stylua` for formatting (`make fmt`) and `luacheck` for linting (`make lint`).
- Prefer explicit names and small helper functions over large monolithic blocks.
- Keep functions focused and avoid side effects where possible.

## Documentation
- Keep docs concise, with clear headings and short paragraphs.
- Prefer step-by-step instructions for setup or workflows.
- Link to other docs rather than duplicating content.

## Tests
- Place tests in `tests/` alongside relevant fixtures.
- Ensure tests are deterministic and do not depend on network access.
- Use the minimal init (`tests/minimal_init.lua`) for Neovim test runs.
