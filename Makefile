LUAROCKS ?= luarocks
ROCKTREE ?= $(HOME)/.local

.PHONY: default all test deps lint clean

default: test

deps:
	@echo "Installing test dependencies into $(ROCKTREE)..."
	@$(LUAROCKS) install --tree=$(ROCKTREE) vusted
	@$(LUAROCKS) install --tree=$(ROCKTREE) luacheck
	@$(LUAROCKS) install --tree=$(ROCKTREE) luafilesystem
	@$(LUAROCKS) install --tree=$(ROCKTREE) penlight
	@$(LUAROCKS) install --tree=$(ROCKTREE) lpeg
	@$(LUAROCKS) install --tree=$(ROCKTREE) plenary.nvim
	@echo "✔ All dependencies installed."

test:
	@echo "Running tests..."
	@$(ROCKTREE)/bin/vusted tests/minimal_init.lua ./tests

lint:
	@echo "Linting Lua code..."
	@$(ROCKTREE)/bin/luacheck lua tests

clean:
	@echo "Cleaning up test artifacts..."
	@rm -rf .test_nvim_data

