-- Unit tests that run without souther or a JDK installed.
-- Integration tests against a live souther-lsp live in tests/integration/lsp_spec.lua.

local eq = assert.are.same

local function open_sou_buffer()
  local path = vim.fn.tempname() .. ".sou"
  vim.fn.writefile({ "// sample", "behavior sumAll : (xs: List<Int>) -> Int" }, path)
  vim.cmd.edit(path)
  return vim.api.nvim_get_current_buf()
end

describe("filetype", function()
  it("detects .sou as souther", function()
    local buf = open_sou_buffer()
    eq("souther", vim.bo[buf].filetype)
  end)
end)

describe("ftplugin", function()
  it("sets comment and indent options", function()
    local buf = open_sou_buffer()
    eq("// %s", vim.bo[buf].commentstring)
    eq("://", vim.bo[buf].comments)
    eq(4, vim.bo[buf].shiftwidth)
    eq(4, vim.bo[buf].softtabstop)
    eq(true, vim.bo[buf].expandtab)
  end)

  it("registers undo_ftplugin", function()
    local buf = open_sou_buffer()
    assert.is_string(vim.b[buf].undo_ftplugin)
  end)
end)

describe("server.argv", function()
  local server = require("souther.server")
  local souther = require("souther")
  local original_executable = vim.fn.executable
  local original_notify_once = vim.notify_once

  before_each(function()
    souther.options = { java = nil, jar = nil, adequacy = "off" }
  end)

  after_each(function()
    vim.fn.executable = original_executable
    vim.notify_once = original_notify_once
  end)

  it("uses `souther lsp` when souther is on PATH", function()
    vim.fn.executable = function(name)
      return name == "souther" and 1 or 0
    end
    eq({ "souther", "lsp" }, server.argv())
  end)

  it("prefers the configured jar over PATH", function()
    vim.fn.executable = function()
      return 1
    end
    souther.setup({ jar = "/opt/souther/souther-lsp.jar" })
    eq({ "java", "-Xss4m", "-jar", "/opt/souther/souther-lsp.jar" }, server.argv())
  end)

  it("uses the configured java with the jar", function()
    souther.setup({ jar = "/opt/souther/souther-lsp.jar", java = "/opt/jdk25/bin/java" })
    eq({ "/opt/jdk25/bin/java", "-Xss4m", "-jar", "/opt/souther/souther-lsp.jar" }, server.argv())
  end)

  it("expands ~ in the jar path", function()
    souther.setup({ jar = "~/souther-lsp.jar" })
    local argv = server.argv()
    eq(vim.fn.expand("~/souther-lsp.jar"), argv[4])
  end)

  it("warns once and still returns `souther lsp` when nothing is installed", function()
    vim.fn.executable = function()
      return 0
    end
    local warnings = {}
    vim.notify_once = function(msg, level)
      table.insert(warnings, { msg = msg, level = level })
    end
    eq({ "souther", "lsp" }, server.argv())
    eq(1, #warnings)
    eq(vim.log.levels.WARN, warnings[1].level)
    assert.truthy(warnings[1].msg:find("brew install", 1, true))
  end)
end)

describe("setup", function()
  local souther = require("souther")

  before_each(function()
    souther.options = { java = nil, jar = nil, adequacy = "off" }
  end)

  it("pushes adequacy into the LSP config", function()
    souther.setup({ adequacy = "witness" })
    eq({ souther = { adequacy = "witness" } }, vim.lsp.config.souther.init_options)
  end)

  it("keeps defaults when called with no options", function()
    souther.setup()
    eq("off", souther.options.adequacy)
    eq(nil, souther.options.jar)
  end)

  it("rejects an unknown adequacy level", function()
    assert.has_error(function()
      souther.setup({ adequacy = "everything" })
    end)
  end)
end)

describe("lsp config", function()
  it("targets the souther filetype and build-file roots", function()
    local config = vim.lsp.config.souther
    eq({ "souther" }, config.filetypes)
    eq({ { "pom.xml", "build.gradle.kts", "build.gradle" }, ".git" }, config.root_markers)
    assert.is_function(config.cmd)
  end)
end)
