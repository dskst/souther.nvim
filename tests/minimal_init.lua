-- Minimal init for running the test suite in isolation.
--
-- Usage:
--   nvim --headless -u tests/minimal_init.lua \
--     -c "PlenaryBustedDirectory tests/unit { minimal_init = 'tests/minimal_init.lua' }"
--
-- plenary.nvim is cloned into .tests/ on first run (or PLENARY_DIR can point
-- at an existing checkout).

vim.o.swapfile = false
vim.o.loadplugins = false

local root = vim.fn.fnamemodify(vim.fn.expand("<sfile>:p"), ":h:h")
local plenary = os.getenv("PLENARY_DIR") or (root .. "/.tests/plenary.nvim")

if vim.fn.isdirectory(plenary) == 0 then
  vim.fn.system({
    "git",
    "clone",
    "--depth",
    "1",
    "https://github.com/nvim-lua/plenary.nvim",
    plenary,
  })
end

vim.opt.runtimepath:prepend(root)
vim.opt.runtimepath:append(plenary)

-- 'loadplugins' is off, so enable filetype detection and ftplugins by hand.
vim.cmd("filetype plugin indent on")
vim.cmd("runtime plugin/plenary.vim")
vim.cmd("runtime plugin/souther.lua")
