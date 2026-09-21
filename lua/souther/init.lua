--- souther.nvim public API.
---
--- There is no `setup()`. The plugin registers the filetype and enables the
--- server on load, and everything about the client --- `cmd`, `init_options`,
--- `root_dir`, `on_attach`, `capabilities` --- is configured through
--- |vim.lsp.config|, the same as for any other language server: >lua
---   vim.lsp.config("souther", {
---     init_options = { souther = { adequacy = "witness" } },
---   })
--- <
local M = {}

--- Values souther-lsp accepts for `init_options.souther.adequacy`.
--- Anything else, `"off"` included, means the measurement is disabled.
M.ADEQUACY_LEVELS = { "off", "witness", "all" }

--- Build a `cmd` that runs souther-lsp from a jar. See |souther-jar_cmd|.
---@param jar string
---@param opts souther.JarOpts|nil
---@return string[]
function M.jar_cmd(jar, opts)
  return require("souther.server").jar_cmd(jar, opts)
end

--- Workspace root souther-lsp would be given for a path. See |souther-root|.
---@param path string
---@return string|nil
function M.root(path)
  return require("souther.root").find(path)
end

return M
