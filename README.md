# souther.nvim

Neovim support for the [Souther](https://souther-lang.org) language: filetype
detection, buffer settings, a fallback syntax file, and a wired-up
`souther-lsp` for highlighting, diagnostics, go-to-definition, hover,
completion, rename, code actions and formatting.

Highlighting comes from the language server's semantic tokens, which know
context-aware identifier roles (type vs. value, parameter vs. local) that no
regex can. A small `syntax/souther.vim` covers the cases the server cannot:
the seconds before a JVM process attaches, buffers it never attaches to (diff
views, fuzzy-finder previews), and machines where `souther` is not installed.
Semantic tokens are applied at a higher priority, so they win wherever they
land.

## Requirements

- Neovim 0.11 or later (uses `vim.lsp.config` / `vim.lsp.enable`)
- The `souther` command line on your `PATH` — it bundles the language server:

  ```sh
  brew install souther-lang/souther/souther     # macOS / Linux
  scoop bucket add souther https://github.com/souther-lang/scoop-souther
  scoop install souther                          # Windows
  ```

  Alternatively, download `souther-lsp.jar` from a
  [release](https://github.com/souther-lang/souther/releases) and point `cmd`
  at it (see [Configuration](#configuration)). The jar needs a JDK 25.

## Compatibility

| souther.nvim | souther / souther-lsp | Neovim |
| ------------ | --------------------- | ------ |
| 0.1.x        | 0.2.x                 | 0.11+  |

## Installation

With [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{ "dskst/souther.nvim", ft = "souther" }
```

That is enough: the plugin registers the filetype and enables the server on
load. Open any `.sou` file and `:checkhealth vim.lsp` should show `souther`
attached.

## Configuration

There is no `setup()`. Everything about the client is configured through
`vim.lsp.config`, the same as for any other language server, before the first
`.sou` buffer is opened:

```lua
vim.lsp.config("souther", {
  -- How much of what `example` rows cover the server measures.
  -- "witness" | "all"; anything else, "off" included, disables it.
  init_options = { souther = { adequacy = "witness" } },

  on_attach = function(client, bufnr) end,
})
```

To run the server from a jar instead of the `souther` launcher, `jar_cmd`
builds the command — including `-Xss4m`, which the compiler requires:

```lua
vim.lsp.config("souther", {
  cmd = require("souther").jar_cmd("~/tools/souther-lsp.jar", {
    java = "/opt/jdk25/bin/java",   -- optional; defaults to `java` on PATH
    jvm_args = { "-Xmx2g" },        -- optional; appended after -Xss4m
  }),
})
```

`cmd` is an ordinary list, so `cmd_env`, `cmd_cwd` and everything else
Neovim does with a command keep working.

## Workspace root

souther-lsp does not read build files. It walks its root recursively, collects
every `*.sou` under it, and compiles them as one flat module set — so an
import only resolves when both files sit under the same root, and a root that
is too narrow is reported as an unknown module rather than degrading quietly.
The root is captured once at `initialize`; the server does not handle
`workspace/didChangeWorkspaceFolders`.

The plugin therefore resolves the *widest* sane boundary, not the nearest one:

1. The nearest ancestor holding a build file (`settings.gradle(.kts)`,
   `pom.xml`, `build.gradle(.kts)`), then upward while each parent also holds
   one — in a Maven or Gradle multi-module tree that is the aggregator, so
   sibling modules resolve against each other.
2. Never above the `.git` directory.
3. With no build file anywhere, the `.git` directory.
4. Otherwise nothing, and the client runs without a workspace, which is the
   right answer for a lone `.sou` file.

`:checkhealth souther` reports the root the current buffer would get. To use
your own rule, override `root_dir` — it takes precedence over `root_markers`,
so setting markers alone would have no effect here:

```lua
vim.lsp.config("souther", {
  root_dir = function(bufnr, on_dir)
    on_dir(vim.fs.root(bufnr, { "souther.toml", ".git" }))
  end,
})
```

## Highlight groups

Semantic tokens land on Neovim's standard `@lsp.type.*` groups, which link to
`@keyword`, `@string`, `@type`, `@function` and so on. Any colorscheme that
handles those works unchanged. To tweak one:

```lua
vim.api.nvim_set_hl(0, "@lsp.type.typeParameter.souther", { link = "@type" })
```

The fallback syntax file uses `souther*` groups linked to the standard `Keyword`,
`String`, `Type`, `Comment` and friends. Use `:Inspect` to see which group a
given token actually received.

## Development

```sh
make test              # unit tests, no souther needed
make test-integration  # needs `souther` on PATH or SOUTHER_LSP_JAR=...
make lint              # stylua --check + luacheck
```

Tests use [plenary.nvim](https://github.com/nvim-lua/plenary.nvim), cloned
into `.tests/` on first run.

## Roadmap

- Tree-sitter queries once a `tree-sitter-souther` grammar exists upstream.
  Nothing else in this plugin changes when it does; the grammar layers
  between the fallback syntax and the semantic tokens.
- Upstreaming `lsp/souther.lua` to nvim-lspconfig. It is deliberately plain
  data so that it merges predictably if both end up on the runtimepath; what
  stays here afterwards is the filetype, buffer settings, syntax fallback and
  health check.
- Reporting `fake` / `example` / `examples for` as keywords in souther-lsp
  itself, so every editor benefits rather than each one carrying the rule.

## License

[MIT](LICENSE)
