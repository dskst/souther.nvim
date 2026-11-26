---
name: verify-workspace-root
description: Check souther.nvim's workspace root resolution (lua/souther/root.lua) against the rule that README.md and doc/souther.txt state, for every directory layout up to four levels deep. Use it after a change to root.lua, to the build file list, to the "Workspace root" section of README.md or to the souther-root section of doc/souther.txt, or when you investigate a report that the root is wrong.
---

# Exhaustive check of the workspace root rule

## What is checked

The property: `require("souther.root").find(path)` returns the directory that the four rules in README.md ("Workspace root") and doc/souther.txt (`*souther-root*`) give.

1. Start at the nearest directory that holds a build file (`settings.gradle.kts`, `settings.gradle`, `pom.xml`, `build.gradle.kts` or `build.gradle`), then move up while each parent also holds one.
2. Never go above the directory that holds the `.git` entry, whether that entry is a directory or a file.
3. With no build file in range, return the `.git` directory.
4. With neither, return `nil`.

The harm when it breaks: souther-lsp compiles only the `*.sou` files under its root, as one module set, and it receives the root once, at `initialize`. A root that is too narrow turns an import into an unknown module. A root that is too wide pulls in unrelated `.sou` files. Either way, the fix needs a server restart.

## How it is checked, and the bounds

No verifier runs on Lua, so the check runs the real `find` on the real filesystem for every layout in range.

- **Layouts:** the script makes `L1/L2/L3/L4` in a temporary directory. Each level has a build file or not, and a `.git` directory, a `.git` file or neither. The script builds all 6^4 combinations.
- **Build file names:** the names rotate through five offsets, so every level gets each of the five names.
- **Calls:** for each layout, the script calls `find` on `L4/a.sou` and on `L4` itself, 12,960 calls over 6,480 layouts. It compares each answer with `expected()`, which computes the answer from the four rules without using the code under test.
- **Shorter paths:** a layout whose top levels are empty is the same as a shorter path, so every path up to four levels deep is covered.

Out of scope:

- Paths five or more levels deep. `nvim -u NONE -l tests/verify/root.lua 5` checks depth 5 in about 9 seconds.
- `M.root_dir`, which passes the buffer name to `find`, and the wiring in `lsp/souther.lua`. The unit tests cover both.
- Relative paths, `~`, trailing slashes, start paths that contain symlinks, start paths that do not exist, and Windows paths.
- Markers above the temporary directory.
- A build file name that exists as a directory.

## When to run it

Run it after a change to any of these:

- `lua/souther/root.lua`
- the "Workspace root" section of README.md
- the `*souther-root*` section of doc/souther.txt
- `tests/verify/root.lua`

## Run

```sh
make verify-root
```

It takes about 1.5 seconds. Through make, every failure exits with status 2, so read the output to tell the cases apart. If you run `nvim -u NONE -l tests/verify/root.lua` directly, 0 means PASS, 1 means a counterexample, and 2 means the check cannot run.

- `PASS: every answer matches the documented rule` means the rule holds for every layout in range.
- `FAIL <kind>: <count> calls. Fewest markers:` is followed by the counterexample with the fewest markers, what `find` returned and what the rule gives.
- A single line on stderr that starts with `verify-root:` means the check cannot run as written. See "Modelling errors" below.

## Known result at the sync commit

At the sync commit, the output has exactly one FAIL kind:

```
FAIL above the .git entry (rule 2): 4380 calls. Fewest markers:
  L1/settings.gradle
  L1/L2/.git/
  root.find("L1/L2/L3/L4/a.sou") returned L1; the rule gives L1/L2
```

This is a real bug, not yet fixed. When a repository (the directory with `.git`) holds no build file and a directory outside it does, `find` returns a directory above `.git` and breaks rule 2. For example, with `~/work/pom.xml` and `~/work/app/.git`, and no build file in `app`, the root becomes the whole of `~/work`. The cause is the `vim.fs.find` call that looks for the nearest build file: it keeps searching past `.git`. All 4,380 calls are in that situation: no build file at or below the `.git` entry, and one above it. The count matches a hand count of those layouts.

If the output shows another FAIL kind, or a different count, your change altered the behavior the rule describes. Once the bug is fixed the check passes. Update this section to PASS then.

## Reading a counterexample

Build the layout from a FAIL to reproduce it with the real code:

```sh
d=$(mktemp -d) && mkdir -p $d/L1/L2/.git $d/L1/L2/L3/L4 && touch $d/L1/settings.gradle $d/L1/L2/L3/L4/a.sou
nvim -u NONE --headless --cmd "set rtp^=." -c "lua print(require('souther').root('$d/L1/L2/L3/L4/a.sou'))" -c q
```

Apply the four rules to the layout by hand. If your answer matches "the rule gives", the bug is in the code. If it does not, the error is in the model.

## Modelling errors

A modelling error is one of these:

- **Wrong expectation:** `expected()` in `tests/verify/root.lua` does not follow the rules in README.md and doc/souther.txt. Fix `expected()`, not the product code.
- **Build file list drift:** if the output is `verify-root: M.BUILD_FILES is ... but the docs name ...`, the code's build file list and the docs disagree. If the change is intended, update README.md, doc/souther.txt and `SPEC_BUILD_FILES` in the script together.
- **Environment:** if the output is `verify-root: ... exists above the sandbox`, the temporary directory is inside a project. Point `TMPDIR` outside any project and run the check again.

Never weaken the property or narrow the bounds to make a counterexample go away.

## When you change the rule on purpose

Update README.md, doc/souther.txt and `expected()` in `tests/verify/root.lua` (and `SPEC_BUILD_FILES` if needed) in the same change. Then confirm that the check can still fail. Break `lua/souther/root.lua` for a moment, for example by replacing `while outermost ~= ceiling do` with `while true do`, and check that the output changes. Restore the file with `git checkout -- lua/souther/root.lua`.

## Coverage and sync commit

| Part of the check | Code it covers |
| --- | --- |
| `SPEC_BUILD_FILES` and the list drift check | `M.BUILD_FILES` in `lua/souther/root.lua` |
| Rule 1 in `expected()` (start at the nearest build file and move up) | the `vim.fs.find(M.BUILD_FILES, ...)` call and the `while` loop in `M.find`, and `has_build_file` |
| Rules 2 and 3 in `expected()` (stop at `.git`, fall back to `.git`) | `git_dir`, and the handling of `ceiling` in `M.find` |
| Rule 4 in `expected()`, and the start path | the empty-path check and the `isdirectory` branch in `M.find` |

Sync commit: `00cecd2012bc4fabc5cbb01b579067d526fb1c6b`

At this commit, the check was confirmed to describe the code in the table above. To see whether that code changed since then, run:

```sh
git diff 00cecd2012bc4fabc5cbb01b579067d526fb1c6b -- lua/souther/root.lua README.md doc/souther.txt
```

If there is a diff, confirm that the check still describes the code. If needed, fix `expected()` and the table, run `make verify-root`, and update the known result. Move the sync commit forward only after all of that is done.
