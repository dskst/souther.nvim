--- Workspace root resolution for souther-lsp.
---
--- souther-lsp does not read build files. It walks its root recursively,
--- collects every `*.sou` under it and compiles them as one flat module set,
--- so an import only resolves when both files sit under the same root. A root
--- that is too narrow does not degrade gracefully: the import is reported as
--- an unknown module. The root is also captured once, at `initialize` --- the
--- server does not handle `workspace/didChangeWorkspaceFolders` --- so getting
--- it wrong means a restart, not a recovery.
---
--- The widest useful boundary is therefore wanted, not the nearest one:
---
---   1. Find the nearest ancestor holding a build file.
---   2. Walk up while each parent also holds one, and take the outermost. In a
---      Maven or Gradle multi-module tree that is the aggregator, so sibling
---      modules resolve against each other.
---   3. Never go above the `.git` directory: an unrelated build file further
---      up the filesystem is not part of this project.
---   4. With no build file anywhere, fall back to the `.git` directory.
---
--- Returning `nil` is deliberate: Neovim then starts the client without a
--- root, which is the right answer for a lone `.sou` file.
local M = {}

--- Build files that mark a project or a module, in no particular order:
--- presence is what matters, not which one.
M.BUILD_FILES = {
  "settings.gradle.kts",
  "settings.gradle",
  "pom.xml",
  "build.gradle.kts",
  "build.gradle",
}

---@param dir string
---@return boolean
local function has_build_file(dir)
  for _, name in ipairs(M.BUILD_FILES) do
    if vim.uv.fs_stat(dir .. "/" .. name) then
      return true
    end
  end
  return false
end

--- Directory holding the `.git` entry above `start`, if any.
---@param start string
---@return string|nil
local function git_dir(start)
  local found = vim.fs.find(".git", { path = start, upward = true, limit = 1 })[1]
  return found and vim.fs.dirname(found) or nil
end

--- Resolve the workspace root for a file or directory.
---@param path string  A `.sou` file or a directory.
---@return string|nil
function M.find(path)
  if path == nil or path == "" then
    return nil
  end

  local start = vim.fs.normalize(path)
  if vim.fn.isdirectory(start) == 0 then
    start = vim.fs.dirname(start)
  end

  local ceiling = git_dir(start)

  local nearest = vim.fs.find(M.BUILD_FILES, { path = start, upward = true, limit = 1 })[1]
  if not nearest then
    return ceiling
  end

  local outermost = vim.fs.dirname(nearest)
  while outermost ~= ceiling do
    local parent = vim.fs.dirname(outermost)
    if parent == outermost or not has_build_file(parent) then
      break
    end
    outermost = parent
  end

  return outermost
end

--- `root_dir` for |vim.lsp.config|.
---@param bufnr integer
---@param on_dir fun(dir: string|nil)
function M.root_dir(bufnr, on_dir)
  on_dir(M.find(vim.api.nvim_buf_get_name(bufnr)))
end

return M
