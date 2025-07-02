export PATH := $(HOME)/.local/bin:/opt/homebrew/bin:$(PATH)

export VUSTED_NVIM := /opt/homebrew/bin/nvim

LUAROCKS := luarocks
ROCKTREE := $(HOME)/.local
VUSTED_BIN := $(ROCKTREE)/bin/vusted

export VUSTED_USE_LOCAL = 1
export VUSTED = --headless -u $(CURDIR)/tests/minimal_init.lua

.PHONY: default all
default: test

.PHONY: deps
deps:
	@echo "Installing test deps into $(ROCKTREE)…"
	@$(LUAROCKS) install --tree=$(ROCKTREE) vusted
	@$(LUAROCKS) install --tree=$(ROCKTREE) luacheck
	@$(LUAROCKS) install --tree=$(ROCKTREE) luafilesystem
	@$(LUAROCKS) install --tree=$(ROCKTREE) penlight
	@$(LUAROCKS) install --tree=$(ROCKTREE) lpeg
	@$(LUAROCKS) install --tree=$(ROCKTREE) plenary.nvim
	@echo "→ All dependencies installed into $(ROCKTREE)."

.PHONY: test
test:
	@echo "Running tests under LuaJIT rock-tree with your custom vusted…"
	@LUA_PATH="`$(LUAROCKS) --tree=$(ROCKTREE) path --lua-version=5.1 --lr-path`":$$LUA_PATH \
	 LUA_CPATH="`$(LUAROCKS) --tree=$(ROCKTREE) path --lua-version=5.1 --lr-cpath`":$$LUA_CPATH \
	 $(VUSTED_BIN) ./tests 2>&1 | tee test.log

.PHONY: lint
lint:
	@echo "Linting Lua code…"
	@luacheck lua tests

.PHONY: clean
clean:
	@echo "Cleaning up test artifacts…"
	@rm -rf .test_nvim_data
