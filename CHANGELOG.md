# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Changed

- Targets souther 0.5.x. `jar_cmd()` adds `-XX:+UseCompactObjectHeaders`
  after `-Xss4m`. Together they are the JVM arguments that souther 0.5.0
  states as required.
- The fallback syntax now comes from the TextMate grammar that souther
  releases ship. `syntax/souther.tmLanguage.json` holds the 0.5.0 copy byte
  for byte, and `lua/souther/syntax.lua` translates it when the first Souther
  buffer loads. `make grammar` replaces the copy after checking it against
  the release's `SHA256SUMS`.
- Fallback groups are named after their TextMate scopes, for example
  `southerKeywordOperator`. An override of an old name such as
  `southerDeclaration` no longer applies. `if`, `then`, `else`, `match`,
  `guard` and `unreachable` link to `Keyword` instead of `Conditional`.
- The fallback marks a builtin type such as `List` as `Type` only when it
  qualifies a name, as in `List.map`. `Rational` joins the list.

### Removed

- The fallback's own rule for `fake`, `example` and `examples for`.
  souther-lsp 0.5.0 reports them as keywords.

### Fixed

- In the fallback, the escape in `"a\"b"` is highlighted as an escape rather
  than an error, and `1.5m` is highlighted as one number, dot included.

## [0.1.0] - 2026-09-22

### Added

- Filetype detection for `.sou` files, in `ftdetect/` so that a plugin manager
  can defer the plugin on `ft = "souther"`.
- Buffer settings matching the VS Code extension (`//` comments, 4-space indent).
- `souther-lsp` wiring via `vim.lsp.config`, launched as `souther lsp` from
  `PATH` or as `java -Xss4m -jar` when `cmd` points at a jar.
- `syntax/souther.vim`, a fallback for the seconds before the JVM server
  attaches, for buffers it never attaches to, and for machines without
  `souther` installed. It also covers `fake` / `example` / `examples for`,
  which souther-lsp currently reports as plain variables.
- `require("souther").jar_cmd()` for building the jar command, and
  `require("souther").root()` for inspecting root resolution.
- `:checkhealth souther` reporting Neovim version, the command the client will
  run, the Java runtime, the adequacy option and the resolved workspace root.
- Unit tests (plenary) and CI for Neovim stable and nightly, with all actions
  pinned to commit SHAs. Integration tests run weekly as well as on tags,
  because souther-lsp moves independently of this plugin.

### Notes on the design

- `cmd` is a plain list rather than a function, so `cmd_env` and `cmd_cwd`
  reach the server and `:checkhealth vim.lsp` can show the command.
- The workspace root is resolved upward to the outermost build file, bounded
  by `.git`. souther-lsp compiles every `.sou` under its root as one flat
  module set and does not read build files, so the nearest build file is the
  wrong answer in a multi-module tree.
- There is no `setup()`. `vim.lsp.config` is the single configuration surface.
- `lsp/souther.lua` asserts the values it pulls out of `lua/souther/`. A nil
  raises nothing on its own -- `vim.deepcopy(nil)` is nil and a nil value drops
  its key from the table -- so the client would otherwise start with no `cmd`
  at all, visible only as "cmd is a nil" in `:checkhealth souther`. That check
  now reports a missing `cmd` as an error, with the stale module cache and the
  duplicate runtimepath entry named as the causes.
