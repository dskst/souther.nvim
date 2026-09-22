-- Language server definition for `vim.lsp.config`.
--
-- Read lazily by Neovim when the `souther` config is first accessed, i.e. when
-- the first `.sou` buffer is opened. Everything here is plain data so that it
-- merges predictably with a user's own `vim.lsp.config("souther", ...)` and
-- with nvim-lspconfig, should this definition be upstreamed.
--
-- `cmd` is a list rather than a function on purpose: a function would have to
-- re-implement `cmd_env`, `cmd_cwd` and the "not executable" report that
-- Neovim already does, and it hides the command from `:checkhealth vim.lsp`.
--
-- Everything pulled out of `lua/souther/` is asserted first. A nil would not
-- raise here: `vim.deepcopy(nil)` is nil, and a nil value simply drops its key
-- from the returned table, so the client would silently end up with no `cmd`
-- (or no `root_dir`) and `:checkhealth souther` could only say "cmd is a nil".

local server = require("souther.server")
local root = require("souther.root")

local STALE_CACHE = "stale Lua module cache, or a second copy of souther.nvim on the runtimepath"

assert(server.DEFAULT_CMD, "souther.server.DEFAULT_CMD is missing: " .. STALE_CACHE)
assert(root.root_dir, "souther.root.root_dir is missing: " .. STALE_CACHE)

return {
  cmd = vim.deepcopy(server.DEFAULT_CMD),
  filetypes = { "souther" },
  -- souther-lsp compiles every `.sou` under its root as one module set and
  -- does not read build files, so the widest sane boundary is wanted. See
  -- `lua/souther/root.lua` for why this is a function and not `root_markers`.
  root_dir = root.root_dir,
  init_options = { souther = { adequacy = "off" } },
}
