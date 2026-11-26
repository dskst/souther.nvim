-- Bounded exhaustive check of the workspace root rule in `lua/souther/root.lua`.
--
-- Builds every ancestor chain of up to DEPTH directories on the real
-- filesystem, each directory holding a build file or not and a `.git`
-- directory, a `.git` file or neither. It calls the real `root.find` on a
-- `.sou` at the bottom and on the bottom directory itself, and compares the
-- answer with the rule that README.md and doc/souther.txt state. A shorter
-- chain is covered too: it is a deeper one whose top directories are empty.
--
-- Usage: make verify-root, or nvim -u NONE -l tests/verify/root.lua [depth]
-- Exit status: 0 the rule holds, 1 a counterexample was found, 2 the check
-- could not run as written (see the message).

local repo = vim.fn.fnamemodify(arg[0], ":p:h:h:h")
vim.opt.runtimepath:prepend(repo)
local root = require("souther.root")

local DEPTH = tonumber(arg[1]) or 4

-- The build files the docs name. Kept apart from M.BUILD_FILES so that a name
-- dropped from the code is caught.
local SPEC_BUILD_FILES =
  { "settings.gradle.kts", "settings.gradle", "pom.xml", "build.gradle.kts", "build.gradle" }

local GIT_KINDS = { false, "dir", "file" }

local function stop(msg)
  io.stderr:write("verify-root: " .. msg .. "\n")
  vim.cmd.cquit(2)
end

local function say(msg)
  io.stdout:write(msg .. "\n")
end

local function touch(path)
  local fd = assert(vim.uv.fs_open(path, "w", 420))
  vim.uv.fs_close(fd)
end

do
  local spec, code = vim.deepcopy(SPEC_BUILD_FILES), vim.deepcopy(root.BUILD_FILES)
  table.sort(spec)
  table.sort(code)
  if not vim.deep_equal(spec, code) then
    stop(
      "M.BUILD_FILES is "
        .. table.concat(code, ", ")
        .. " but the docs name "
        .. table.concat(spec, ", ")
        .. ". Update SPEC_BUILD_FILES together with README.md and doc/souther.txt."
    )
  end
end

local base = vim.fs.normalize(
  assert(
    vim.uv.fs_realpath(assert(vim.uv.fs_mkdtemp(vim.uv.os_tmpdir() .. "/souther-root-XXXXXX")))
  )
)

for dir in vim.fs.parents(base .. "/x") do
  for _, name in ipairs(vim.list_extend({ ".git" }, SPEC_BUILD_FILES)) do
    if vim.uv.fs_stat(dir .. "/" .. name) then
      vim.fn.delete(base, "rf")
      stop(dir .. "/" .. name .. " exists above the sandbox. Set TMPDIR outside any project.")
    end
  end
end

-- Markers are switched in place across shapes.
local rel, dirs, level_of = {}, {}, {}
for i = 1, DEPTH do
  rel[i] = (rel[i - 1] and rel[i - 1] .. "/" or "") .. "L" .. i
  dirs[i] = base .. "/" .. rel[i]
  level_of[dirs[i]] = i
end
assert(vim.fn.mkdir(dirs[DEPTH], "p") == 1)
local sou = dirs[DEPTH] .. "/a.sou"
touch(sou)

local current = {}
for i = 1, DEPTH do
  current[i] = { build = false, git = false }
end

local function sync(i, want)
  local dir, have = dirs[i], current[i]
  if have.build ~= want.build then
    if have.build then
      assert(vim.uv.fs_unlink(dir .. "/" .. have.build))
    end
    if want.build then
      touch(dir .. "/" .. want.build)
    end
  end
  if have.git ~= want.git then
    if have.git == "dir" then
      assert(vim.uv.fs_rmdir(dir .. "/.git"))
    elseif have.git == "file" then
      assert(vim.uv.fs_unlink(dir .. "/.git"))
    end
    if want.git == "dir" then
      assert(vim.uv.fs_mkdir(dir .. "/.git", 493))
    elseif want.git == "file" then
      touch(dir .. "/.git")
    end
  end
  current[i] = want
end

--- The documented rule, by level. Returns the level of the root (0: none) and
--- the level of the `.git` entry (0: none).
local function expected(levels)
  local ceiling = 0
  for i = DEPTH, 1, -1 do
    if levels[i].git then
      ceiling = i
      break
    end
  end
  local floor = math.max(ceiling, 1)
  local nearest = 0
  for i = DEPTH, floor, -1 do
    if levels[i].build then
      nearest = i
      break
    end
  end
  if nearest == 0 then
    return ceiling, ceiling
  end
  local top = nearest
  while top > floor and levels[top - 1].build do
    top = top - 1
  end
  return top, ceiling
end

local function classify(want, got, ceiling)
  if got == false then
    return "a root outside the tree"
  elseif got > 0 and ceiling > 0 and got < ceiling then
    return "above the .git entry (rule 2)"
  elseif want == 0 then
    return "a root where the rule gives none (rule 4)"
  elseif got == 0 then
    return "no root where the rule gives one (rules 1 and 3)"
  elseif got > want then
    return "narrower than the rule (rule 1)"
  else
    return "wider than the rule (rule 1)"
  end
end

local function show(level)
  return level == 0 and "nil" or rel[level]
end

local function describe_case(case)
  local lines = {}
  for i = 1, DEPTH do
    local lv = case.levels[i]
    if lv.build then
      lines[#lines + 1] = "  " .. rel[i] .. "/" .. lv.build
    end
    if lv.git == "dir" then
      lines[#lines + 1] = "  " .. rel[i] .. "/.git/"
    elseif lv.git == "file" then
      lines[#lines + 1] = "  " .. rel[i] .. "/.git (a file, as in a worktree or submodule)"
    end
  end
  if #lines == 0 then
    lines[1] = "  (no build file, no .git)"
  end
  local got = case.got == false and case.got_path or show(case.got)
  lines[#lines + 1] = string.format(
    '  root.find("%s") returned %s; the rule gives %s',
    case.start,
    got,
    show(case.want)
  )
  return table.concat(lines, "\n")
end

local states = 2 * #GIT_KINDS
local shapes = states ^ DEPTH
local failures, order, calls = {}, {}, 0

for rotation = 0, #SPEC_BUILD_FILES - 1 do
  for shape = 0, shapes - 1 do
    local levels, markers, n = {}, 0, shape
    for i = 1, DEPTH do
      local s = n % states
      n = math.floor(n / states)
      local build = s % 2 == 1 and SPEC_BUILD_FILES[(i + rotation) % #SPEC_BUILD_FILES + 1]
      local git = GIT_KINDS[math.floor(s / 2) + 1]
      levels[i] = { build = build, git = git }
      markers = markers + (build and 1 or 0) + (git and 1 or 0)
      sync(i, levels[i])
    end

    local want, ceiling = expected(levels)
    for _, start in ipairs({ sou, dirs[DEPTH] }) do
      calls = calls + 1
      local path = root.find(start)
      local got = path == nil and 0 or level_of[path] or false
      if got ~= want then
        local kind = classify(want, got, ceiling)
        local f = failures[kind]
        if not f then
          f = { count = 0 }
          failures[kind] = f
          order[#order + 1] = kind
        end
        f.count = f.count + 1
        if not f.case or markers < f.case.markers then
          f.case = {
            levels = levels,
            markers = markers,
            start = start:sub(#base + 2),
            want = want,
            got = got,
            got_path = path,
          }
        end
      end
    end
  end
end

vim.fn.delete(base, "rf")

say(
  string.format(
    "verify-root: depth %d, %d trees, %d calls to root.find",
    DEPTH,
    shapes * #SPEC_BUILD_FILES,
    calls
  )
)
if #order == 0 then
  say("PASS: every answer matches the documented rule")
  vim.cmd.cquit(0)
end
for _, kind in ipairs(order) do
  local f = failures[kind]
  say(string.format("\nFAIL %s: %d calls. Fewest markers:", kind, f.count))
  say(describe_case(f.case))
end
vim.cmd.cquit(1)
