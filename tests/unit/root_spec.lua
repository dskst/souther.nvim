-- Workspace root resolution.
--
-- souther-lsp compiles every `.sou` under its root as one module set and does
-- not read build files, so these tests are about width: an aggregator must win
-- over the module the file happens to sit in, and nothing above `.git` counts.

local eq = assert.are.same

local root = require("souther.root")

local function tree(spec)
  local base = vim.fs.normalize(vim.fn.tempname())
  for _, rel in ipairs(spec) do
    local path = base .. "/" .. rel
    if rel:sub(-1) == "/" then
      vim.fn.mkdir(path, "p")
    else
      vim.fn.mkdir(vim.fs.dirname(path), "p")
      vim.fn.writefile({ "" }, path)
    end
  end
  -- On macOS `$TMPDIR` sits under `/var`, a symlink to `/private/var`, and
  -- `:edit` records the resolved path in the buffer name. Describe the tree by
  -- its real path so expectations match whichever side built the string.
  return vim.fs.normalize(vim.uv.fs_realpath(base) or base)
end

describe("root.find", function()
  it("takes the project directory for a single-module project", function()
    local base = tree({ "proj/pom.xml", "proj/src/main/souther/a.sou" })
    eq(base .. "/proj", root.find(base .. "/proj/src/main/souther/a.sou"))
  end)

  it("takes the aggregator, not the module, in a Maven multi-module tree", function()
    local base = tree({
      "repo/.git/HEAD",
      "repo/pom.xml",
      "repo/member/pom.xml",
      "repo/member/src/main/souther/member.sou",
      "repo/order/pom.xml",
      "repo/order/src/main/souther/order.sou",
    })
    eq(base .. "/repo", root.find(base .. "/repo/member/src/main/souther/member.sou"))
  end)

  it("takes the settings directory in a Gradle multi-project tree", function()
    local base = tree({
      "repo/settings.gradle.kts",
      "repo/member/build.gradle.kts",
      "repo/member/src/main/souther/member.sou",
    })
    eq(base .. "/repo", root.find(base .. "/repo/member/src/main/souther/member.sou"))
  end)

  it("never climbs above the .git directory", function()
    local base = tree({
      "outer/pom.xml",
      "outer/repo/.git/HEAD",
      "outer/repo/pom.xml",
      "outer/repo/src/main/souther/a.sou",
    })
    eq(base .. "/outer/repo", root.find(base .. "/outer/repo/src/main/souther/a.sou"))
  end)

  it("falls back to the .git directory when there is no build file", function()
    local base = tree({ "repo/.git/HEAD", "repo/src/a.sou" })
    eq(base .. "/repo", root.find(base .. "/repo/src/a.sou"))
  end)

  it("returns nil for a lone file, so the client runs without a root", function()
    local base = tree({ "loose/a.sou" })
    eq(nil, root.find(base .. "/loose/a.sou"))
  end)

  it("accepts a directory as well as a file", function()
    local base = tree({ "proj/pom.xml", "proj/src/main/souther/" })
    eq(base .. "/proj", root.find(base .. "/proj/src/main/souther"))
  end)

  it("returns nil for an empty path", function()
    eq(nil, root.find(""))
    eq(nil, root.find(nil))
  end)
end)

describe("root.root_dir", function()
  it("hands the resolved root to the callback", function()
    local base = tree({ "proj/pom.xml", "proj/src/main/souther/a.sou" })
    vim.cmd.edit(base .. "/proj/src/main/souther/a.sou")
    local buf = vim.api.nvim_get_current_buf()

    local got, called = nil, false
    root.root_dir(buf, function(dir)
      got, called = dir, true
    end)

    assert.is_true(called)
    eq(base .. "/proj", got)
    vim.cmd.bwipeout({ buf, bang = true })
  end)
end)
