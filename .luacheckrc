std = "luajit"
cache = true
codes = true

-- `vim` is writable so that option tables (vim.bo.x = ...) and test doubles
-- (vim.fn.executable = ...) do not trip W122.
globals = { "vim" }

files["tests/**/*.lua"] = {
  read_globals = {
    "describe",
    "it",
    "pending",
    "before_each",
    "after_each",
    "assert",
  },
}

-- Line length is enforced by stylua.
max_line_length = false
