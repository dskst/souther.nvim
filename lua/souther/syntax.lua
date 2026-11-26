local M = {}

local LINKS = {
  ["comment"] = "Comment",
  ["constant.character.escape"] = "SpecialChar",
  ["constant.language.boolean"] = "Boolean",
  ["constant.numeric"] = "Number",
  ["invalid"] = "Error",
  ["keyword"] = "Keyword",
  ["keyword.operator"] = "Operator",
  ["string"] = "String",
  ["support.class"] = "Type",
  ["variable"] = "Identifier",
}

local RULE_KEYS = { name = true, match = true, begin = true, ["end"] = true, patterns = true }

-- What takes a backslash inside a Vim collection. Before any other character
-- Vim keeps the backslash as a literal one.
local CLASS_SPECIAL = { ["\\"] = true, ["]"] = true, ["^"] = true, ["-"] = true }

local DELIMITERS = { "/", "!", ",", ";", ":", "~", "@" }

local function unsupported(construct, where)
  error(
    ("souther.syntax: %s uses %s, which this translator does not support"):format(where, construct),
    0
  )
end

local function link_for(scope)
  local prefix = scope
  while prefix do
    if LINKS[prefix] then
      return LINKS[prefix]
    end
    prefix = prefix:match("^(.+)%.[^.]+$")
  end
  error(("souther.syntax: no highlight group for scope %q"):format(scope), 0)
end

local function group_for(scope)
  local words = scope:gsub("%.souther$", ""):gsub("%w+", function(word)
    return word:sub(1, 1):upper() .. word:sub(2)
  end)
  return "souther" .. words:gsub("%W", "")
end

---@param p string
---@param i integer  the index of the `[` that opens the class
---@param where string
---@return string vim_class
---@return integer next_index
local function translate_class(p, i, where)
  local out = { "[" }
  i = i + 1
  if p:sub(i, i) == "^" then
    unsupported("[^", where)
  end
  while p:sub(i, i) ~= "]" do
    local c = p:sub(i, i)
    if c == "" or c == "[" or p:sub(i, i + 1) == "&&" then
      unsupported(
        c == "" and "an unterminated [" or (c == "[" and "[ inside a class" or "&&"),
        where
      )
    elseif c ~= "\\" then
      out[#out + 1] = c
      i = i + 1
    else
      local hex, after = p:match("^x{(%x+)}()", i + 1)
      local e = p:sub(i + 1, i + 1)
      if hex then
        local n = tonumber(hex, 16)
        out[#out + 1] = n <= 0xFFFF and ("\\u%04X"):format(n) or ("\\U%08X"):format(n)
        i = after
      elseif e:match("^%p$") then
        out[#out + 1] = (CLASS_SPECIAL[e] and "\\" or "") .. e
        i = i + 2
      else
        unsupported("\\" .. e .. " inside a class", where)
      end
    end
  end
  return table.concat(out) .. "]", i + 1
end

--- Groups become non-capturing, because Vim allows only nine captures. The NFA
--- engine is forced: the backtracking one rejects a multibyte range wider than
--- 256 characters, and the type-variable rule is made of them.
---@param p string
---@param where string  the rule, for error messages
---@return string
local function translate(p, where)
  local out, closers, i = { "\\%#=2\\v" }, {}, 1
  local after_quantifier = false
  while i <= #p do
    local c = p:sub(i, i)
    local quantifier = c == "?" or c == "*" or c == "+"
    if quantifier and after_quantifier then
      unsupported("the lazy or possessive quantifier " .. p:sub(i - 1, i), where)
    end
    if c == "\\" then
      local e = p:sub(i + 1, i + 1)
      if e == "b" then
        out[#out + 1] = "%(<|>)"
      elseif e == "s" then
        out[#out + 1] = "\\s"
      elseif e:match("^%p$") then
        out[#out + 1] = "\\" .. e
      else
        unsupported("\\" .. e, where)
      end
      i = i + 2
    elseif c == "[" then
      out[#out + 1], i = translate_class(p, i, where)
    elseif p:sub(i, i + 2) == "(?=" then
      out[#out + 1], closers[#closers + 1] = "%(", ")@="
      i = i + 3
    elseif p:sub(i, i + 1) == "(?" then
      unsupported(p:match("^%(%?<?.", i), where)
    elseif c == "(" then
      out[#out + 1], closers[#closers + 1] = "%(", ")"
      i = i + 1
    elseif c == ")" then
      out[#out + 1] = table.remove(closers) or unsupported("an unbalanced )", where)
      i = i + 1
    elseif quantifier or c == "|" or c == "." or c == "$" then
      out[#out + 1] = c
      i = i + 1
    elseif c == "^" or c == "{" then
      unsupported(c, where)
    elseif c:match("^%p$") and c ~= "_" then
      -- Literal in Oniguruma; with a backslash, literal in Vim's \v too.
      out[#out + 1] = "\\" .. c
      i = i + 1
    else
      out[#out + 1] = c
      i = i + 1
    end
    after_quantifier = quantifier
  end
  if #closers > 0 then
    unsupported("an unclosed (", where)
  end
  return table.concat(out)
end

local function delimit(pattern, where)
  for _, d in ipairs(DELIMITERS) do
    if not pattern:find(d, 1, true) then
      return d .. pattern .. d
    end
  end
  error(("souther.syntax: no free delimiter for %s"):format(where), 0)
end

---@param grammar table  a decoded TextMate grammar
---@return string[]
function M.commands(grammar)
  local out, linked = {}, {}

  --- TextMate tries `patterns` in order and the first rule to match at a
  --- position wins. In Vim the item defined last wins, so the rules are defined
  --- in reverse. Returns the groups `rules` define, for a region's `contains=`.
  ---@return string[]
  local function define(rules, label, contained)
    local groups, seen = {}, {}
    for n = #rules, 1, -1 do
      local rule, where = rules[n], ("%s pattern %d"):format(label, n)
      if rule.include then
        where = rule.include
        rule = rule.include:match("^#") and grammar.repository[rule.include:sub(2)]
          or error(("souther.syntax: cannot resolve include %q"):format(where), 0)
      end
      for key in pairs(rule) do
        if not RULE_KEYS[key] then
          unsupported("the rule key " .. key, where)
        end
      end
      if type(rule.name) ~= "string" or not (rule.match or (rule.begin and rule["end"])) then
        unsupported("a rule that is neither a named match nor a named begin/end pair", where)
      end

      local group = group_for(rule.name)
      local opts = contained and " contained" or ""
      if rule.match then
        out[#out + 1] = ("syn match %s %s%s"):format(
          group,
          delimit(translate(rule.match, where), where),
          opts
        )
      else
        local children = define(rule.patterns or {}, where, true)
        if #children > 0 then
          opts = opts .. " contains=" .. table.concat(children, ",")
        end
        out[#out + 1] = ("syn region %s start=%s end=%s%s"):format(
          group,
          delimit(translate(rule.begin, where), where),
          delimit(translate(rule["end"], where), where),
          opts
        )
      end

      if not seen[group] then
        seen[group] = true
        groups[#groups + 1] = group
      end
      if not linked[group] then
        linked[group] = true
        out[#out + 1] = ("hi def link %s %s"):format(group, link_for(rule.name))
      end
    end
    return groups
  end

  define(grammar.patterns, "the grammar", false)
  return out
end

local cached

function M.apply()
  if not cached then
    local path = vim.api.nvim_get_runtime_file("syntax/souther.tmLanguage.json", false)[1]
    cached = M.commands(vim.json.decode(table.concat(vim.fn.readfile(path), "\n")))
  end
  for _, command in ipairs(cached) do
    vim.cmd(command)
  end
end

return M
