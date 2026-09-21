-- Integration tests against a live souther-lsp.
--
-- Skipped unless `souther` is on PATH (or SOUTHER_LSP_JAR is set), so the
-- default `make test` run stays JDK-free. CI runs these weekly and on tagged
-- pushes -- weekly because the server moves independently of this plugin.

local eq = assert.are.same

local jar = os.getenv("SOUTHER_LSP_JAR")
local available = (jar ~= nil and jar ~= "") or vim.fn.executable("souther") == 1

local function wait_for(pred, timeout_ms)
  return vim.wait(timeout_ms or 20000, pred, 100)
end

local function client_for(buf)
  return vim.lsp.get_clients({ bufnr = buf, name = "souther" })[1]
end

local function wait_for_client(buf)
  assert.truthy(wait_for(function()
    return client_for(buf) ~= nil
  end))
  return client_for(buf)
end

describe("souther-lsp integration", function()
  if not available then
    pending("souther is not installed; skipping integration tests")
    return
  end

  local dir, buf

  local function open(path)
    vim.cmd.edit(path)
    buf = vim.api.nvim_get_current_buf()
    return buf
  end

  before_each(function()
    if jar and jar ~= "" then
      vim.lsp.config("souther", { cmd = require("souther").jar_cmd(jar) })
    end
    dir = vim.fn.tempname()
  end)

  after_each(function()
    for _, client in ipairs(vim.lsp.get_clients({ bufnr = buf })) do
      client:stop(true)
    end
    vim.cmd.bwipeout({ buf, bang = true })
  end)

  describe("a single-module project", function()
    before_each(function()
      vim.fn.mkdir(dir .. "/src/main/souther", "p")
      vim.fn.writefile({ "<project/>" }, dir .. "/pom.xml")
      local path = dir .. "/src/main/souther/sample.sou"
      vim.fn.writefile({
        "// a comment",
        "behavior sumAll : (xs: List<Int>) -> Int",
      }, path)
      open(path)
    end)

    it("attaches with the pom.xml directory as root", function()
      local client = wait_for_client(buf)
      eq(vim.fs.normalize(dir), vim.fs.normalize(client.root_dir))
    end)

    it("returns a keyword semantic token for `behavior`", function()
      wait_for_client(buf)
      assert.truthy(wait_for(function()
        local tokens = vim.lsp.semantic_tokens.get_at_pos(buf, 1, 0) or {}
        return #tokens > 0
      end))
      local tokens = vim.lsp.semantic_tokens.get_at_pos(buf, 1, 0)
      eq("keyword", tokens[1].type)
    end)

    it("publishes a diagnostic for a syntax error", function()
      wait_for_client(buf)
      vim.api.nvim_buf_set_lines(buf, -1, -1, false, { "behavior broken : (" })
      assert.truthy(wait_for(function()
        return #vim.diagnostic.get(buf) > 0
      end))
    end)
  end)

  describe("a multi-module project", function()
    -- The point of resolving the root upward: souther-lsp compiles every
    -- `.sou` under one root as a single module set, so a sibling module is
    -- only visible when the aggregator, not the module, is the root.
    before_each(function()
      vim.fn.mkdir(dir, "p")
      vim.fn.writefile({ "<project/>" }, dir .. "/pom.xml")
      for _, module in ipairs({ "member", "order" }) do
        vim.fn.mkdir(dir .. "/" .. module .. "/src/main/souther", "p")
        vim.fn.writefile({ "<project/>" }, dir .. "/" .. module .. "/pom.xml")
      end
      vim.fn.writefile({
        "module order",
        "",
        "behavior orderCount : () -> Int",
      }, dir .. "/order/src/main/souther/order.sou")
      open(dir .. "/member/src/main/souther/member.sou")
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "module member", "", "import order" })
      vim.cmd.write()
    end)

    it("takes the aggregator as root, not the module the file sits in", function()
      local client = wait_for_client(buf)
      eq(vim.fs.normalize(dir), vim.fs.normalize(client.root_dir))
    end)

    it("resolves an import of a sibling module", function()
      wait_for_client(buf)
      -- Give the server a diagnose pass, then assert nothing complains about
      -- the import itself: an out-of-root sibling is reported as unknown.
      vim.wait(3000, function()
        return false
      end, 100)
      for _, d in ipairs(vim.diagnostic.get(buf)) do
        assert.is_nil(d.message:lower():find("unknown module"))
      end
    end)
  end)
end)
