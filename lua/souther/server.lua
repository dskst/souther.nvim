--- Helpers for pointing `cmd` at a souther-lsp.
---
--- There is no plugin-level option layer: `cmd` is an ordinary list in
--- `lsp/souther.lua` and is overridden the same way as for any other server,
--- through |vim.lsp.config|. This module only builds the list for the jar
--- route, which is the one command that is easy to get wrong.
local M = {}

--- What `lsp/souther.lua` ships. The `souther` launcher brings its own JVM.
M.DEFAULT_CMD = { "souther", "lsp" }

--- Stack size the Souther compiler documents as required. Not a tuning knob:
--- the `souther` launcher sets the same value for itself.
M.REQUIRED_JVM_ARGS = { "-Xss4m" }

M.INSTALL_HINT = table.concat({
  "souther.nvim: `souther` was not found on PATH.",
  "Install it with `brew install souther-lang/souther/souther`,",
  "or point `cmd` at a jar:",
  "vim.lsp.config('souther', { cmd = require('souther').jar_cmd('/path/to/souther-lsp.jar') }).",
}, " ")

---@class souther.JarOpts
---@field java string|nil        Java executable. Defaults to `java` on PATH. Needs a JDK 25.
---@field jvm_args string[]|nil  Extra JVM arguments, appended after `-Xss4m`.

--- Build a `cmd` that runs souther-lsp from a jar.
---
--- >lua
---   vim.lsp.config("souther", {
---     cmd = require("souther").jar_cmd("~/tools/souther-lsp.jar", {
---       java = "/opt/jdk25/bin/java",
---       jvm_args = { "-Xmx2g" },
---     }),
---   })
--- <
---@param jar string
---@param opts souther.JarOpts|nil
---@return string[]
function M.jar_cmd(jar, opts)
  vim.validate("jar", jar, "string")
  vim.validate("opts", opts, "table", true)
  opts = opts or {}
  vim.validate("opts.java", opts.java, "string", true)
  vim.validate("opts.jvm_args", opts.jvm_args, "table", true)

  local cmd = { opts.java or "java" }
  vim.list_extend(cmd, M.REQUIRED_JVM_ARGS)
  vim.list_extend(cmd, opts.jvm_args or {})
  vim.list_extend(cmd, { "-jar", vim.fn.expand(jar) })
  return cmd
end

--- Whether `cmd` is still the shipped default, i.e. nothing was configured.
---@param cmd string[]|function|nil
---@return boolean
function M.is_default_cmd(cmd)
  return type(cmd) == "table" and vim.deep_equal(cmd, M.DEFAULT_CMD)
end

return M
