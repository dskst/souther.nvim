# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added

- Filetype detection for `.sou` files.
- Buffer settings matching the VS Code extension (`//` comments, 4-space indent).
- `souther-lsp` wiring via `vim.lsp.config`, launched as `souther lsp` from
  `PATH` or as `java -Xss4m -jar` when a jar is configured.
- `require("souther").setup()` with `jar`, `java` and `adequacy` options.
- Unit tests (plenary) and CI for Neovim stable and nightly.
