--- Resolves the command used to launch souther-lsp.
---
--- Resolution order:
---   1. `java -Xss4m -jar <jar>` when `setup({ jar = ... })` was given.
---   2. `souther lsp` when the `souther` binary is on PATH.
---   3. `souther lsp` anyway, after a one-time warning with install hints.
---      Neovim then reports the spawn failure itself, so the buffer stays
---      editable and the reason is visible.
---
--- `-Xss4m` is the stack size the compiler documents as required, not a
--- tuning knob. The `souther` launcher sets it for itself.
local M = {}

M.INSTALL_HINT = table.concat({
  "souther.nvim: `souther` was not found on PATH.",
  "Install it with `brew install souther-lang/souther/souther`,",
  "or point the plugin at a jar: require('souther').setup({ jar = '/path/to/souther-lsp.jar' }).",
}, " ")

--- Build the argv for the language server process.
---@return string[]
function M.argv()
  local opts = require("souther").options

  if opts.jar and opts.jar ~= "" then
    return { opts.java or "java", "-Xss4m", "-jar", vim.fn.expand(opts.jar) }
  end

  if vim.fn.executable("souther") ~= 1 then
    vim.notify_once(M.INSTALL_HINT, vim.log.levels.WARN)
  end

  return { "souther", "lsp" }
end

return M
