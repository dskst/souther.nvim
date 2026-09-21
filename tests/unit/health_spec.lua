-- Tests for `:checkhealth souther`. vim.health is stubbed so the report can
-- be inspected as a list of {level, message} pairs.

local eq = assert.are.same

local souther = require("souther")
local health = require("souther.health")

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

describe("health", function()
  before_each(function()
    souther.options = { java = nil, jar = nil, adequacy = "off" }
    stub_health()
  end)

  after_each(function()
    vim.health = original_health
    vim.fn.executable = original_executable
    vim.fn.exepath = original_exepath
    package.loaded["souther.health"] = nil
  end)

  it("reports ok when souther is on PATH", function()
    vim.fn.executable = function(name)
      return name == "souther" and 1 or 0
    end
    vim.fn.exepath = function()
      return "/opt/homebrew/bin/souther"
    end
    health.check()
    assert.truthy(has("ok", "/opt/homebrew/bin/souther"))
    assert.truthy(has("info", "souther lsp"))
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
    souther.setup({ jar = "/nonexistent/souther-lsp.jar" })
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
    souther.setup({ jar = jar })
    vim.fn.executable = function()
      return 0
    end
    health.check()
    assert.truthy(has("ok", jar))
  end)

  it("always reports the adequacy option", function()
    souther.setup({ adequacy = "witness" })
    vim.fn.executable = function()
      return 0
    end
    health.check()
    assert.truthy(has("info", "adequacy: witness"))
  end)

  it("reports the Neovim version", function()
    vim.fn.executable = function()
      return 0
    end
    health.check()
    eq("start", report[1][1])
    eq("Neovim", report[1][2])
  end)
end)
