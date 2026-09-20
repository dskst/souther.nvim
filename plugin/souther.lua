-- Entry point loaded once at startup.
--
-- Registers the `souther` filetype for `.sou` files and enables the language
-- server. Everything else (buffer options, server command resolution) is
-- loaded lazily when the first `.sou` buffer is opened.

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

vim.filetype.add({ extension = { sou = "souther" } })
vim.lsp.enable("souther")
