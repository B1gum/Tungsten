LUAROCKS ?= luarocks
ROCKTREE ?= $(HOME)/.luarocks

.PHONY: default all test deps lint clean test_deps lint_deps

default: test

all: deps lint test

ci: lint test

deps: test_deps lint_deps
	@echo "✔ All dependencies installed."

test_deps:
	@echo "Installing test dependencies into $(ROCKTREE)..."
	@$(LUAROCKS) install --tree=$(ROCKTREE) vusted
	@$(LUAROCKS) install --tree=$(ROCKTREE) luafilesystem
	@$(LUAROCKS) install --tree=$(ROCKTREE) penlight
	@$(LUAROCKS) install --tree=$(ROCKTREE) lpeg
	@$(LUAROCKS) install --tree=$(ROCKTREE) lpeglabel
	@scripts/install_plenary.sh
	@echo "✔ All test dependencies installed."


lint_deps:
	@echo "Installing lint dependencies into $(ROCKTREE)..."
	@$(LUAROCKS) install --tree=$(ROCKTREE) luacheck
	@echo "✔ All lint dependencies installed."

test: test_deps
	@echo "Running tests..."
	@$(ROCKTREE)/bin/vusted tests/minimal_init.lua ./tests

lint: lint_deps
	@echo "Linting Lua code..."
	@$(ROCKTREE)/bin/luacheck lua tests

clean:
	@echo "Cleaning up test artifacts..."
	@rm -rf .test_nvim_data
