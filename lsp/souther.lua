-- Language server definition for `vim.lsp.config`.
--
-- This file is read lazily by Neovim when the `souther` config is first
-- accessed, i.e. when the first `.sou` buffer is opened. The server command
-- is resolved inside `cmd` on every client start so that PATH changes and
-- `require("souther").setup()` calls made after startup are honored.

local server = require("souther.server")

return {
  cmd = function(dispatchers, config)
    local argv = server.argv()
    return vim.lsp.rpc.start(argv, dispatchers, { cwd = config.cmd_cwd })
  end,
  filetypes = { "souther" },
  -- Build files take priority over `.git`: souther-lsp resolves names across
  -- modules from the workspace root, and a monorepo's `.git` is too wide.
  root_markers = { { "pom.xml", "build.gradle.kts", "build.gradle" }, ".git" },
  init_options = { souther = { adequacy = "off" } },
}
