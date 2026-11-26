# Not `NVIM`: Neovim sets $NVIM to its RPC socket inside :terminal, which would shadow this.
NVIM_BIN ?= nvim
MINIMAL_INIT := tests/minimal_init.lua

.PHONY: test test-integration verify-root lint format

# Unit tests: no souther or JDK required.
test:
	$(NVIM_BIN) --headless -u $(MINIMAL_INIT) \
		-c "PlenaryBustedDirectory tests/unit { minimal_init = '$(MINIMAL_INIT)', sequential = true }"

# Integration tests: need `souther` on PATH or SOUTHER_LSP_JAR set.
test-integration:
	$(NVIM_BIN) --headless -u $(MINIMAL_INIT) \
		-c "PlenaryBustedDirectory tests/integration { minimal_init = '$(MINIMAL_INIT)', sequential = true }"

# Every directory tree up to a bound, checked against the documented root rule.
verify-root:
	$(NVIM_BIN) -u NONE -l tests/verify/root.lua

lint:
	luacheck lua plugin ftplugin ftdetect lsp tests
	stylua --check lua plugin ftplugin ftdetect lsp tests

format:
	stylua lua plugin ftplugin ftdetect lsp tests
