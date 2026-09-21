-- Filetype detection, kept out of `plugin/` on purpose.
--
-- A lazy-loading plugin manager that is told `ft = "souther"` will not load
-- `plugin/` until a buffer already has the `souther` filetype. If the
-- extension mapping lived there, nothing would ever set that filetype and the
-- plugin would never load. `ftdetect/` is sourced at startup even for a
-- plugin that is otherwise deferred, so the mapping is always in place.

vim.filetype.add({ extension = { sou = "souther" } })
