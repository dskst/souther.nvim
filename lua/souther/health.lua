--- `:checkhealth souther`
---
--- Reports the things that usually go wrong in the field: Neovim version,
--- whether a server can be launched (and how), and the Java runtime when
--- the jar route is in use. Nothing here starts the server.
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

local function check_jar(opts)
  local jar = vim.fn.expand(opts.jar)
  if vim.fn.filereadable(jar) == 1 then
    health.ok("jar: " .. jar)
  else
    health.error("jar not found: " .. jar, {
      "Fix the path in require('souther').setup({ jar = ... })",
      "Or unset it to use `souther lsp` from PATH",
    })
  end

  local java = opts.java or "java"
  if vim.fn.executable(java) ~= 1 then
    health.error("java not executable: " .. java, {
      "Install a JDK 25 or set require('souther').setup({ java = '/path/to/java' })",
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
      "Point `java` at a JDK 25 or use `souther lsp`, which brings its own runtime",
    })
  end
end

local function check_server()
  health.start("Language server")
  local opts = require("souther").options

  if opts.jar and opts.jar ~= "" then
    health.info("launch: java -Xss4m -jar <jar> (configured via setup)")
    check_jar(opts)
    return
  end

  if vim.fn.executable("souther") == 1 then
    local path = vim.fn.exepath("souther")
    local version = run({ "souther", "version" })
    health.ok("souther: " .. path .. (version and (" (" .. version .. ")") or ""))
    health.info("launch: souther lsp")
    return
  end

  health.error("`souther` is not on PATH and no jar is configured", {
    "brew install souther-lang/souther/souther",
    "or: require('souther').setup({ jar = '/path/to/souther-lsp.jar' })",
  })
end

local function check_options()
  health.start("Options")
  local opts = require("souther").options
  health.info("adequacy: " .. tostring(opts.adequacy))
end

function M.check()
  check_neovim()
  check_server()
  check_options()
end

return M
