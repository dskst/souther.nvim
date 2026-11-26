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
  -- Neovim's default colors link Keyword to Statement, Number to Constant and
  -- so on. Defining each standard group directly, as a colorscheme does, stops
  -- the link chain at the group the syntax file chose.
  before_each(function()
    for _, group in ipairs({
      "Boolean",
      "Comment",
      "Error",
      "Identifier",
      "Keyword",
      "Number",
      "Operator",
      "SpecialChar",
      "String",
      "Type",
    }) do
      vim.api.nvim_set_hl(0, group, {})
    end
  end)

  local function group_at(row, col)
    return vim.fn.synIDattr(vim.fn.synIDtrans(vim.fn.synID(row, col, 1)), "name")
  end

  it("loads without the language server", function()
    open_sou_buffer()
    eq("souther", vim.b.current_syntax)
  end)

  it("highlights a comment to the end of the line", function()
    open_sou_buffer({ "// a comment" })
    eq("Comment", group_at(1, 1))
    eq("Comment", group_at(1, 12))
  end)

  it("keeps a string with an escaped quote in it as one string", function()
    open_sou_buffer({ [[let s = "a\"b" ++ t]] })
    eq("String", group_at(1, 9))
    eq("SpecialChar", group_at(1, 11))
    eq("SpecialChar", group_at(1, 12))
    eq("String", group_at(1, 13))
    eq("String", group_at(1, 14))
    eq("Operator", group_at(1, 16))
  end)

  it("marks an unknown escape as an error", function()
    open_sou_buffer({ [["a\qb"]] })
    eq("Error", group_at(1, 3))
    eq("Error", group_at(1, 4))
    eq("String", group_at(1, 5))
  end)

  it("highlights decimals and integers", function()
    open_sou_buffer({ "let x = 1.5m + 42" })
    eq("Number", group_at(1, 9))
    eq("Number", group_at(1, 10))
    eq("Number", group_at(1, 12))
    eq("Operator", group_at(1, 14))
    eq("Number", group_at(1, 16))
  end)

  it("highlights booleans", function()
    open_sou_buffer({ "let ok = true" })
    eq("Boolean", group_at(1, 10))
  end)

  it("highlights declaration keywords", function()
    open_sou_buffer({ "behavior sumAll : (xs: List<Int>) -> Int" })
    eq("Keyword", group_at(1, 1))
    eq("", group_at(1, 10))
  end)

  it("highlights `depends on` as one keyword", function()
    open_sou_buffer({ "depends on member" })
    eq("Keyword", group_at(1, 1))
    eq("Keyword", group_at(1, 9))
    eq("", group_at(1, 12))
  end)

  it("highlights control keywords", function()
    open_sou_buffer({ "if ok then 1 else 2" })
    eq("Keyword", group_at(1, 1))
    eq("Keyword", group_at(1, 7))
  end)

  it("highlights ASCII and non-ASCII type variables", function()
    open_sou_buffer({ "behavior id : (x: 'a) -> 'αβ" })
    eq("Identifier", group_at(1, 19))
    eq("Identifier", group_at(1, 20))
    eq("", group_at(1, 21))
    eq("Identifier", group_at(1, 26))
    eq("Identifier", group_at(1, 29))
  end)

  it("highlights a builtin type only where it qualifies a name", function()
    open_sou_buffer({ "List.map", "Rational.x", "xs: List<Int>" })
    eq("Type", group_at(1, 1))
    eq("Type", group_at(2, 1))
    eq("", group_at(3, 5))
  end)

  it("highlights operators", function()
    open_sou_buffer({ "a -> b >-> c <?> d |> e" })
    eq("Operator", group_at(1, 3))
    eq("Operator", group_at(1, 8))
    eq("Operator", group_at(1, 14))
    eq("Operator", group_at(1, 20))
  end)

  it("rejects a grammar that uses a regex construct it cannot translate", function()
    local ok, err = pcall(require("souther.syntax").commands, {
      patterns = { { include = "#annotation" } },
      repository = { annotation = { name = "keyword.souther", match = "(?<=@)name" } },
    })
    assert.is_false(ok)
    assert.matches("(?<=", err, 1, true)
  end)
end)

describe("server.jar_cmd", function()
  local server = require("souther.server")

  it("builds a java -jar command with the JVM args the compiler requires", function()
    eq(
      { "java", "-Xss4m", "-XX:+UseCompactObjectHeaders", "-jar", "/opt/souther/souther-lsp.jar" },
      server.jar_cmd("/opt/souther/souther-lsp.jar")
    )
  end)

  it("uses the configured java", function()
    eq("/opt/jdk25/bin/java", server.jar_cmd("/x.jar", { java = "/opt/jdk25/bin/java" })[1])
  end)

  it("appends extra jvm args after the required ones", function()
    eq(
      { "java", "-Xss4m", "-XX:+UseCompactObjectHeaders", "-Xmx2g", "-jar", "/x.jar" },
      server.jar_cmd("/x.jar", { jvm_args = { "-Xmx2g" } })
    )
  end)

  it("expands ~ in the jar path", function()
    local cmd = server.jar_cmd("~/souther-lsp.jar")
    eq(vim.fn.expand("~/souther-lsp.jar"), cmd[#cmd])
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
    eq(
      { "java", "-Xss4m", "-XX:+UseCompactObjectHeaders", "-jar", "/x.jar" },
      souther.jar_cmd("/x.jar")
    )
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
