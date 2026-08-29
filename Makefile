LUAROCKS ?= luarocks
LUA_VERSION ?= 5.1
LUA_DIR ?=

DEPS_DIR ?= $(CURDIR)/.test_deps
ROCKTREE ?= $(DEPS_DIR)/rocks
PLENARY_DIR ?= $(DEPS_DIR)/plenary.nvim

LUAROCKS_FLAGS := --lua-version=$(LUA_VERSION)
ifneq ($(strip $(LUA_DIR)),)
LUAROCKS_FLAGS += --lua-dir=$(LUA_DIR)
endif

export TUNGSTEN_TEST_ROCKTREE := $(ROCKTREE)
export TUNGSTEN_TEST_PLENARY := $(PLENARY_DIR)

.PHONY: default all ci test deps lint clean clean_deps test_deps lint_deps fmt fmt-check cov coverage

default: all

all: deps fmt ci

ci: lint fmt-check test

deps: test_deps lint_deps
	@echo "✔ All dependencies installed."

test_deps:
	@echo "Installing test dependencies into $(ROCKTREE)..."
	@$(LUAROCKS) $(LUAROCKS_FLAGS) install --tree="$(ROCKTREE)" vusted
	@$(LUAROCKS) $(LUAROCKS_FLAGS) install --tree="$(ROCKTREE)" luafilesystem
	@$(LUAROCKS) $(LUAROCKS_FLAGS) install --tree="$(ROCKTREE)" penlight
	@$(LUAROCKS) $(LUAROCKS_FLAGS) install --tree="$(ROCKTREE)" luacov
	@TUNGSTEN_TEST_PLENARY="$(PLENARY_DIR)" scripts/install_plenary.sh
	@echo "✔ All test dependencies installed."

lint_deps:
	@echo "Installing lint dependencies into $(ROCKTREE)..."
	@$(LUAROCKS) $(LUAROCKS_FLAGS) install --tree="$(ROCKTREE)" luacheck
	@echo "✔ All lint dependencies installed."

test: test_deps
	@echo "Running tests..."
	@$(ROCKTREE)/bin/vusted tests/minimal_init.lua ./tests

lint: lint_deps
	@echo "Linting Lua code..."
	@$(ROCKTREE)/bin/luacheck lua tests

fmt:
	@echo "Formatting Lua code with stylua..."
	@stylua lua/ tests/

fmt-check:
	@echo "Checking Lua formatting with stylua..."
	@stylua --check lua/ tests/

clean:
	@echo "Cleaning up test artifacts..."
	@rm -rf .test_nvim_data luacov.stats.out luacov.report.out

clean_deps:
	@echo "Removing repository-local test dependencies..."
	@rm -rf "$(DEPS_DIR)"

cov coverage: test_deps
	@echo "Running tests with coverage..."
	@$(ROCKTREE)/bin/vusted --coverage tests/minimal_init.lua ./tests
	@echo "Generating coverage report..."
	@$(ROCKTREE)/bin/luacov
	@echo "Coverage report generated: luacov.report.out"
	@grep -A999 "^Summary" luacov.report.out || true
