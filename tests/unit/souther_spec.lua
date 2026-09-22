-- Unit tests that run without souther or a JDK installed.
-- Integration tests against a live souther-lsp live in tests/integration/lsp_spec.lua.

local eq = assert.are.same

local function open_sou_buffer(lines)
  local path = vim.fn.tempname() .. ".sou"
  vim.fn.writefile(lines or { "// sample", "behavior sumAll : (xs: List<Int>) -> Int" }, path)
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

describe("syntax fallback", function()
  --- Name of the syntax group the character at (row, col) ended up in.
  local function group_at(row, col)
    return vim.fn.synIDattr(vim.fn.synID(row, col, 1), "name")
  end

  it("loads without the language server", function()
    open_sou_buffer()
    eq("souther", vim.b.current_syntax)
  end)

  it("highlights declarations, comments, strings and numbers", function()
    open_sou_buffer({
      "// a comment",
      'let price = 100m ++ "text"',
    })
    eq("southerComment", group_at(1, 1))
    eq("southerDeclaration", group_at(2, 1))
    eq("southerNumber", group_at(2, 13))
    eq("southerString", group_at(2, 22))
  end)

  it("highlights the contextual keywords the server reports as variables", function()
    open_sou_buffer({
      "fake findByEmail",
      "examples for example.core.Member",
    })
    eq("southerDeclaration", group_at(1, 1))
    eq("southerDeclaration", group_at(2, 1))
    eq("southerExamplesFor", group_at(2, 10))
    -- `example` inside a qualified module name stays a plain name.
    eq("", group_at(2, 14))
  end)
end)

describe("server.jar_cmd", function()
  local server = require("souther.server")

  it("builds a java -jar command with the required stack size", function()
    eq(
      { "java", "-Xss4m", "-jar", "/opt/souther/souther-lsp.jar" },
      server.jar_cmd("/opt/souther/souther-lsp.jar")
    )
  end)

  it("uses the configured java", function()
    eq("/opt/jdk25/bin/java", server.jar_cmd("/x.jar", { java = "/opt/jdk25/bin/java" })[1])
  end)

  it("appends extra jvm args after the required ones", function()
    eq(
      { "java", "-Xss4m", "-Xmx2g", "-jar", "/x.jar" },
      server.jar_cmd("/x.jar", { jvm_args = { "-Xmx2g" } })
    )
  end)

  it("expands ~ in the jar path", function()
    eq(vim.fn.expand("~/souther-lsp.jar"), server.jar_cmd("~/souther-lsp.jar")[4])
  end)

  it("rejects a missing jar path", function()
    assert.has_error(function()
      server.jar_cmd(nil)
    end)
  end)
end)

describe("server.is_default_cmd", function()
  local server = require("souther.server")

  it("recognises the shipped default", function()
    assert.is_true(server.is_default_cmd({ "souther", "lsp" }))
  end)

  it("rejects anything else", function()
    assert.is_false(server.is_default_cmd({ "souther", "lsp", "--verbose" }))
    assert.is_false(server.is_default_cmd(server.jar_cmd("/x.jar")))
    assert.is_false(server.is_default_cmd(nil))
  end)
end)

describe("public API", function()
  local souther = require("souther")

  it("exposes jar_cmd and root", function()
    eq({ "java", "-Xss4m", "-jar", "/x.jar" }, souther.jar_cmd("/x.jar"))
    assert.is_function(souther.root)
  end)

  it("does not ship a setup() function", function()
    eq(nil, souther.setup)
  end)
end)

describe("lsp config", function()
  it("ships a plain list cmd so cmd_env and cmd_cwd keep working", function()
    local config = vim.lsp.config.souther
    eq({ "souther" }, config.filetypes)
    eq({ "souther", "lsp" }, config.cmd)
    eq({ souther = { adequacy = "off" } }, config.init_options)
  end)

  it("resolves the root with a function rather than root_markers", function()
    local config = vim.lsp.config.souther
    eq(nil, config.root_markers)
    assert.is_function(config.root_dir)
  end)
end)
