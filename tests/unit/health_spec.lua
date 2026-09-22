-- Tests for `:checkhealth souther`. vim.health is stubbed so the report can
-- be inspected as a list of {level, message} pairs.

local eq = assert.are.same

local health = require("souther.health")
local server = require("souther.server")

local report
local original_health = vim.health
local original_executable = vim.fn.executable
local original_exepath = vim.fn.exepath

local function stub_health()
  report = {}
  local function record(level)
    return function(msg)
      table.insert(report, { level, msg })
    end
  end
  vim.health = {
    start = record("start"),
    ok = record("ok"),
    info = record("info"),
    warn = record("warn"),
    error = record("error"),
  }
  -- health.lua captured `vim.health` at require time; reload it.
  package.loaded["souther.health"] = nil
  health = require("souther.health")
end

local function levels()
  return vim.tbl_map(function(entry)
    return entry[1]
  end, report)
end

local function has(level, pattern)
  for _, entry in ipairs(report) do
    if entry[1] == level and entry[2]:find(pattern, 1, true) then
      return true
    end
  end
  return false
end

local function set_cmd(cmd)
  vim.lsp.config("souther", { cmd = cmd })
end

-- `vim.lsp.config` merges tables, so a missing `cmd` cannot be arranged
-- through it. Stand a plain table in its place instead.
local function check_with_config(conf)
  local original = vim.lsp.config
  vim.lsp.config = { souther = conf }
  local ok, err = pcall(health.check)
  vim.lsp.config = original
  assert(ok, err)
end

describe("health", function()
  before_each(function()
    set_cmd(vim.deepcopy(server.DEFAULT_CMD))
    stub_health()
  end)

  after_each(function()
    vim.health = original_health
    vim.fn.executable = original_executable
    vim.fn.exepath = original_exepath
    package.loaded["souther.health"] = nil
    set_cmd(vim.deepcopy(server.DEFAULT_CMD))
  end)

  it("reports ok when souther is on PATH", function()
    vim.fn.executable = function(name)
      return name == "souther" and 1 or 0
    end
    vim.fn.exepath = function()
      return "/opt/homebrew/bin/souther"
    end
    health.check()
    assert.truthy(has("info", "cmd: souther lsp"))
    assert.truthy(has("ok", "/opt/homebrew/bin/souther"))
    assert.is_false(vim.tbl_contains(levels(), "error"))
  end)

  it("errors when neither souther nor a jar is available", function()
    vim.fn.executable = function()
      return 0
    end
    health.check()
    assert.truthy(has("error", "not on PATH"))
  end)

  it("errors when the configured jar does not exist", function()
    set_cmd(server.jar_cmd("/nonexistent/souther-lsp.jar"))
    vim.fn.executable = function()
      return 0
    end
    health.check()
    assert.truthy(has("error", "jar not found"))
    assert.truthy(has("error", "java not executable"))
  end)

  it("accepts an existing jar", function()
    local jar = vim.fn.tempname() .. ".jar"
    vim.fn.writefile({ "" }, jar)
    set_cmd(server.jar_cmd(jar))
    vim.fn.executable = function()
      return 0
    end
    health.check()
    assert.truthy(has("ok", jar))
  end)

  it("names a custom cmd that cannot be run", function()
    set_cmd({ "souther-lsp-wrapper", "--stdio" })
    vim.fn.executable = function()
      return 0
    end
    health.check()
    assert.truthy(has("info", "cmd: souther-lsp-wrapper --stdio"))
    assert.truthy(has("error", "not executable: souther-lsp-wrapper"))
  end)

  it("errors when the resolved config has no cmd", function()
    check_with_config({ init_options = { souther = { adequacy = "off" } } })
    assert.truthy(has("error", "no `cmd`"))
  end)

  it("warns when cmd is a function it cannot inspect", function()
    check_with_config({ cmd = function() end })
    assert.truthy(has("warn", "cmd is a function"))
    assert.is_false(vim.tbl_contains(levels(), "error"))
  end)

  it("always reports the adequacy option", function()
    vim.lsp.config("souther", { init_options = { souther = { adequacy = "witness" } } })
    vim.fn.executable = function()
      return 0
    end
    health.check()
    assert.truthy(has("info", "adequacy: witness"))
    vim.lsp.config("souther", { init_options = { souther = { adequacy = "off" } } })
  end)

  it("reports the Neovim version", function()
    vim.fn.executable = function()
      return 0
    end
    health.check()
    eq("start", report[1][1])
    eq("Neovim", report[1][2])
  end)

  it("reports the workspace root of the current buffer", function()
    local base = vim.fs.normalize(vim.fn.tempname())
    vim.fn.mkdir(base .. "/proj/src/main/souther", "p")
    -- macOS resolves `/var` to `/private/var` when `:edit` records the buffer
    -- name, so the expected root has to be the real path. See root_spec.
    base = vim.fs.normalize(vim.uv.fs_realpath(base) or base)
    vim.fn.writefile({ "" }, base .. "/proj/pom.xml")
    local path = base .. "/proj/src/main/souther/a.sou"
    vim.fn.writefile({ "// x" }, path)
    vim.cmd.edit(path)
    local buf = vim.api.nvim_get_current_buf()

    vim.fn.executable = function()
      return 0
    end
    health.check()
    assert.truthy(has("ok", "root: " .. base .. "/proj"))
    vim.cmd.bwipeout({ buf, bang = true })
  end)
end)
