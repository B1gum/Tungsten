export PATH := $(HOME)/.luarocks/bin:$(PATH)

export VUSTED_USE_LOCAL = 1
export VUSTED_ARGS = --headless -u $(CURDIR)/tests/minimal_init.lua

.PHONY: default all
default: test

.PHONY: deps
deps:
	luarocks --local install vusted
	luarocks --local install luacheck
	luarocks --local install luafilesystem
	luarocks --local install penlight
	@echo "All dependencies installed in local LuaRocks tree."

.PHONY: test
test:
	@echo "Running tests with vusted..."
	vusted ./tests 2>&1 | tee test.log

.PHONY: lint
lint:
	@echo "Linting Lua code with luacheck..."
	luacheck lua tests

.PHONY: clean
clean:
	@echo "Cleaning up test artifacts..."
	rm -rf .test_nvim_data

