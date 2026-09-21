-- Entry point loaded once at startup.
--
-- Filetype detection lives in `ftdetect/souther.lua`, not here, so that a
-- plugin manager can defer this file on `ft = "souther"`. All this does is
-- enable the language server and, when the server is plainly not installed,
-- say so once with install hints.

if vim.g.loaded_souther then
  return
end
vim.g.loaded_souther = true

if vim.fn.has("nvim-0.11") ~= 1 then
  vim.notify_once(
    "souther.nvim requires Neovim 0.11 or later (vim.lsp.config is not available).",
    vim.log.levels.ERROR
  )
  return
end

vim.lsp.enable("souther")

-- Neovim reports a failed spawn on its own, but "souther: no such file or
-- directory" does not tell a first-time user what to install. Warn before the
-- client starts, and only while `cmd` is still the default -- someone who
-- configured their own `cmd` does not need PATH advice.
vim.api.nvim_create_autocmd("FileType", {
  pattern = "souther",
  group = vim.api.nvim_create_augroup("souther.install_hint", {}),
  callback = function()
    local server = require("souther.server")
    if server.is_default_cmd(vim.lsp.config.souther.cmd) and vim.fn.executable("souther") ~= 1 then
      vim.notify_once(server.INSTALL_HINT, vim.log.levels.WARN)
    end
  end,
})
