# Contributing

Thanks for helping out. A few conventions keep the plugin small and easy to
review.

## Scope

This plugin wires Neovim to `souther-lsp` and nothing more. Language features
(highlighting rules, diagnostics, formatting) belong in
[souther-lang/souther](https://github.com/souther-lang/souther); please file
them there. Things that belong here: filetype and buffer settings, server
discovery, Neovim-specific glue.

## Workflow

1. Fork and branch from `main`.
2. `make lint` and `make test` must pass. `make format` applies stylua.
3. If a change touches behavior, add or update a test in `tests/`.
4. Add a line under `[Unreleased]` in `CHANGELOG.md`.
5. Open a pull request. Keep the description short: what changed and why.

## Style

- Lua formatted with [stylua](https://github.com/JohnnyMorganz/StyLua)
  (`.stylua.toml`), linted with [luacheck](https://github.com/lunarmodules/luacheck).
  Neither ships with Neovim: `brew install stylua luacheck` on macOS, or grab
  a stylua release binary and `luarocks install luacheck`. CI pins stylua
  v2.5.2 and luacheck v1.2.0.
- Comments and documentation in English.
- Option names mirror the VS Code extension's settings where one exists.

## Running integration tests locally

They need a real server. Either put `souther` on `PATH`
(`brew install souther-lang/souther/souther`) or set
`SOUTHER_LSP_JAR=/path/to/souther-lsp.jar`, then `make test-integration`.
