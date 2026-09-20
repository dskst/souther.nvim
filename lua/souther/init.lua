--- souther.nvim public API.
---
--- Calling `setup()` is optional. Without it the plugin runs `souther lsp`
--- from PATH with the same defaults as the VS Code extension. Option names
--- deliberately match the VS Code extension's settings
--- (`souther.server.jar`, `souther.server.java`, `souther.adequacy`).
local M = {}

--- Valid values for the `adequacy` option, cheapest first.
M.ADEQUACY_LEVELS = { "off", "witness", "all" }

---@class souther.Options
---@field java string|nil   Java executable used with `jar`. Defaults to `java` on PATH.
---@field jar string|nil    Path to souther-lsp.jar. When set, it takes priority over `souther lsp`.
---@field adequacy "off"|"witness"|"all"  How much example coverage the server measures.

---@type souther.Options
M.options = {
  java = nil,
  jar = nil,
  adequacy = "off",
}

local function validate(opts)
  vim.validate("java", opts.java, "string", true)
  vim.validate("jar", opts.jar, "string", true)
  vim.validate("adequacy", opts.adequacy, function(v)
    return vim.tbl_contains(M.ADEQUACY_LEVELS, v)
  end, false, "one of " .. table.concat(M.ADEQUACY_LEVELS, ", "))
end

--- Override the defaults and push them into the `souther` LSP config.
---@param opts souther.Options|nil
function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", M.options, opts or {})
  validate(M.options)

  if vim.fn.has("nvim-0.11") == 1 then
    vim.lsp.config("souther", {
      init_options = { souther = { adequacy = M.options.adequacy } },
    })
  end
end

return M
