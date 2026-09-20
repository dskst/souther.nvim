-- Buffer-local options for the `souther` filetype.
--
-- Values mirror the VS Code extension's language-configuration.json
-- (line comments only, `//`) and souther-fmt's indent width (4 spaces),
-- so a file round-trips between both editors without whitespace churn.

if vim.b.did_ftplugin then
  return
end
vim.b.did_ftplugin = true

vim.bo.commentstring = "// %s"
vim.bo.comments = "://"
vim.bo.shiftwidth = 4
vim.bo.softtabstop = 4
vim.bo.expandtab = true

vim.b.undo_ftplugin = "setlocal commentstring< comments< shiftwidth< softtabstop< expandtab<"
