# souther.nvim

Neovim support for the [Souther](https://souther-lang.org) language: filetype
detection, buffer settings, and a wired-up `souther-lsp` for highlighting,
diagnostics, go-to-definition, hover, completion, rename, code actions and
formatting.

Highlighting comes entirely from the language server's semantic tokens, which
cover keywords, strings, numbers, comments and operators as well as
context-aware identifier roles (type vs. value, parameter vs. local). No
regex syntax file or Tree-sitter grammar is bundled.

## Requirements

- Neovim 0.11 or later (uses `vim.lsp.config` / `vim.lsp.enable`)
- The `souther` command line on your `PATH` — it bundles the language server:

  ```sh
  brew install souther-lang/souther/souther     # macOS / Linux
  scoop bucket add souther https://github.com/souther-lang/scoop-souther
  scoop install souther                          # Windows
  ```

  Alternatively, download `souther-lsp.jar` from a
  [release](https://github.com/souther-lang/souther/releases) and point the
  plugin at it (see [Configuration](#configuration)). The jar needs a JDK 25.

## Installation

With [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{ "dskst/souther.nvim" }
```

That is enough: the plugin registers the filetype and enables the server on
load. Open any `.sou` file and `:LspInfo` should show `souther` attached.

## Configuration

`setup()` is optional. The defaults match the VS Code extension.

```lua
require("souther").setup({
  -- Path to souther-lsp.jar. When set, the plugin runs
  -- `java -Xss4m -jar <jar>` instead of `souther lsp`.
  jar = nil,

  -- Java executable to use with `jar`. Defaults to `java` on PATH.
  java = nil,

  -- How much of what `example` rows cover to measure.
  -- "off" | "witness" | "all"
  adequacy = "off",
})
```

To change anything else about the client (capabilities, `on_attach`, extra
root markers), extend the config the standard way before the first `.sou`
buffer is opened:

```lua
vim.lsp.config("souther", {
  root_markers = { "souther.toml", ".git" },
  on_attach = function(client, bufnr) ... end,
})
```

## How the server is found

1. `setup({ jar = ... })` was given → `java -Xss4m -jar <jar>`
2. `souther` is executable on `PATH` → `souther lsp`
3. Neither → a one-time warning with install hints, then Neovim's own
   "not executable" error. The buffer stays editable.

`-Xss4m` is the stack size the compiler requires, not a tuning knob. The
`souther` launcher sets it for itself, so it is only added for the jar route.

## Highlight groups

Semantic tokens land on Neovim's standard `@lsp.type.*` groups, which link to
`@keyword`, `@string`, `@type`, `@function` and so on. Any colorscheme that
handles those works unchanged. To tweak one:

```lua
vim.api.nvim_set_hl(0, "@lsp.type.typeParameter.souther", { link = "@type" })
```

## Development

```sh
make test              # unit tests, no souther needed
make test-integration  # needs `souther` on PATH or SOUTHER_LSP_JAR=...
make lint              # stylua --check + luacheck
```

Tests use [plenary.nvim](https://github.com/nvim-lua/plenary.nvim), cloned
into `.tests/` on first run.

## Roadmap

- A generated `syntax/souther.vim` as a fallback for the seconds before the
  server attaches, if that gap turns out to matter in practice.
- Tree-sitter queries once a `tree-sitter-souther` grammar exists upstream.
  Nothing in this plugin changes when it does; the grammar layers underneath
  the semantic tokens.
- Upstreaming the server definition to nvim-lspconfig.

## License

[MIT](LICENSE)
