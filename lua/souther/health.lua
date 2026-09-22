--- `:checkhealth souther`
---
--- Reports the things that usually go wrong in the field: Neovim version, the
--- command the client will actually run (and whether it can run), the Java
--- runtime when a jar is configured, and the workspace root the current buffer
--- would be given. Nothing here starts the server.
local M = {}

local health = vim.health

--- Run a command and return trimmed stdout+stderr, or nil when it fails.
---@param argv string[]
---@return string|nil
local function run(argv)
  local ok, result = pcall(function()
    return vim.system(argv, { text = true }):wait()
  end)
  if not ok or result.code ~= 0 then
    return nil
  end
  local out = (result.stdout or "") .. (result.stderr or "")
  return vim.trim(out)
end

--- Parse the major version out of `java -version` output.
---@param java string
---@return integer|nil, string|nil  major version and the first output line
local function java_major(java)
  local ok, result = pcall(function()
    return vim.system({ java, "-version" }, { text = true }):wait()
  end)
  if not ok or result.code ~= 0 then
    return nil, nil
  end
  -- `java -version` prints to stderr, e.g. `openjdk version "25.0.1" 2025-10-21`.
  local text = (result.stderr or "") .. (result.stdout or "")
  local first = vim.split(text, "\n", { plain = true })[1] or ""
  local major = first:match('version "(%d+)')
  return tonumber(major), first
end

--- The effective `souther` client config, or nil when it cannot be read.
---@return table|nil
local function config()
  local ok, conf = pcall(function()
    return vim.lsp.config.souther
  end)
  return ok and conf or nil
end

--- The jar path in a `cmd`, when the command is a `java -jar` invocation.
---@param cmd string[]
---@return string|nil
local function jar_of(cmd)
  for i, arg in ipairs(cmd) do
    if arg == "-jar" then
      return cmd[i + 1]
    end
  end
  return nil
end

local function check_neovim()
  health.start("Neovim")
  if vim.fn.has("nvim-0.11") == 1 then
    local v = vim.version()
    health.ok(
      string.format("Neovim %d.%d.%d (0.11 or later is required)", v.major, v.minor, v.patch)
    )
  else
    health.error("Neovim 0.11 or later is required for vim.lsp.config", {
      "Upgrade Neovim: https://github.com/neovim/neovim/releases",
    })
  end
end

local function check_jar(cmd, jar)
  if vim.fn.filereadable(vim.fn.expand(jar)) == 1 then
    health.ok("jar: " .. jar)
  else
    health.error("jar not found: " .. jar, {
      "Fix the path passed to require('souther').jar_cmd()",
      "Or drop the `cmd` override to use `souther lsp` from PATH",
    })
  end

  local java = cmd[1]
  if vim.fn.executable(java) ~= 1 then
    health.error("java not executable: " .. java, {
      "Install a JDK 25, or pass { java = '/path/to/java' } to jar_cmd()",
    })
    return
  end

  local major, line = java_major(java)
  if major == nil then
    health.warn("could not determine the Java version from `" .. java .. " -version`")
  elseif major >= 25 then
    health.ok("java: " .. (line or java))
  else
    health.error("java: " .. (line or java), {
      "souther-lsp.jar is built for Java 25; this runtime cannot load it",
      "Point `java` at a JDK 25, or use `souther lsp`, which brings its own runtime",
    })
  end
end

local function check_server()
  health.start("Language server")

  local conf = config()
  if conf == nil then
    health.error("the `souther` LSP config could not be read", {
      "Check that lsp/souther.lua is on the runtimepath",
    })
    return
  end

  local cmd = conf.cmd
  if cmd == nil then
    -- Not a configuration choice anyone can make: `vim.lsp.config` merges
    -- tables, so a key can only be missing if the definition never carried it.
    health.error("the resolved `souther` config has no `cmd`", {
      "Stale Lua module cache: run `:lua vim.loader.reset()`, or restart Neovim",
      "Two copies on the runtimepath: :lua =vim.api.nvim_get_runtime_file('lua/souther/server.lua', true)",
      "Or set one yourself: vim.lsp.config('souther', { cmd = { 'souther', 'lsp' } })",
    })
    return
  end

  if type(cmd) ~= "table" then
    health.warn("cmd is a " .. type(cmd) .. ", so it cannot be checked here")
    return
  end

  health.info("cmd: " .. table.concat(cmd, " "))

  local jar = jar_of(cmd)
  if jar then
    check_jar(cmd, jar)
    return
  end

  local exe = cmd[1]
  if vim.fn.executable(exe) == 1 then
    local path = vim.fn.exepath(exe)
    local version = exe == "souther" and run({ exe, "version" }) or nil
    health.ok(exe .. ": " .. path .. (version and (" (" .. version .. ")") or ""))
    return
  end

  if require("souther.server").is_default_cmd(cmd) then
    health.error("`souther` is not on PATH and no jar is configured", {
      "brew install souther-lang/souther/souther",
      "or: vim.lsp.config('souther', { cmd = require('souther').jar_cmd('/path/to/souther-lsp.jar') })",
    })
  else
    health.error("not executable: " .. exe, {
      "Fix the `cmd` passed to vim.lsp.config('souther', ...)",
    })
  end
end

local function check_workspace()
  health.start("Workspace")

  local conf = config()
  local adequacy = vim.tbl_get(conf or {}, "init_options", "souther", "adequacy")
  health.info("adequacy: " .. tostring(adequacy))

  local name = vim.api.nvim_buf_get_name(0)
  if vim.bo.filetype ~= "souther" or name == "" then
    health.info("root: open a .sou file to see the root it resolves to")
    return
  end

  local root = require("souther.root").find(name)
  if root then
    health.ok("root: " .. root)
  else
    health.warn("root: none found; the server would run without a workspace", {
      "souther-lsp resolves imports only among the .sou files under its root",
      "Add a build file (pom.xml, settings.gradle, ...) or a .git at the project top",
    })
  end
end

function M.check()
  check_neovim()
  check_server()
  check_workspace()
end

return M
