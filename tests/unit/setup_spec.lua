-- tests/unit/setup_spec.lua
-- Tests for the Tungsten setup function

local mock_utils = require("tests.helpers.mock_utils")

describe("tungsten.setup", function()
	local tungsten = require("tungsten")
	local defaults

	local function reload_modules()
		mock_utils.reset_modules({
			"tungsten",
			"tungsten.config",
			"tungsten.state",
			"tungsten.cache",
			"tungsten.core.commands",
			"tungsten.core.registry",
			"tungsten.ui.which_key",
			"tungsten.ui",
			"tungsten.core",
		})
	end

	before_each(reload_modules)
	after_each(reload_modules)

	it("keeps config unchanged with nil opts", function()
		local before = vim.deepcopy(tungsten.config)
		tungsten.setup()
		assert.are.same(before, tungsten.config)
		assert.are.same(before, require("tungsten.config"))
	end)

	it("keeps config unchanged with empty table", function()
		local before = vim.deepcopy(tungsten.config)
		tungsten.setup({})
		assert.are.same(before, tungsten.config)
	end)

	it("overrides defaults with user options", function()
		local snapshot = vim.deepcopy(defaults)
		tungsten.setup({ debug = true, process_timeout_ms = 10 })
		local cfg = require("tungsten.config")
		assert.is_true(cfg.debug)
		assert.are.equal(10, cfg.process_timeout_ms)
		assert.are.same(snapshot, defaults)
	end)

	it("throws error for invalid option type", function()
		assert.has_error(function()
			tungsten.setup(42)
		end, "tungsten.setup: options table expected")
	end)

	it("creates user commands from registry", function()
		local mock_registry = {
			commands = {
				{ name = "MockCmd", func = function() end, opts = { desc = "mock" } },
			},
			get_domain_priority = function()
				return 0
			end,
		}
		function mock_registry.register_command(cmd)
			table.insert(mock_registry.commands, cmd)
		end

		package.loaded["tungsten.core.registry"] = mock_registry

		local create_spy = require("luassert.spy").new(function() end)
		local orig_create = vim.api.nvim_create_user_command
		vim.api.nvim_create_user_command = create_spy

		tungsten.setup()

		for _, cmd in ipairs(mock_registry.commands) do
			local expected_opts = cmd.opts or { desc = cmd.desc }
			assert.spy(create_spy).was.called_with(cmd.name, cmd.func, expected_opts)
		end

		vim.api.nvim_create_user_command = orig_create
	end)

	it("initializes cache with user options", function()
		local tungsten = require("tungsten")
		tungsten.setup({ cache_max_entries = 42, cache_ttl = 17 })
		local state = require("tungsten.state")
		assert.are.equal(42, state.cache.max_entries)
		assert.are.equal(17, state.cache.ttl)
	end)

	it("recreates cache when setup is called again", function()
		local tungsten = require("tungsten")
		tungsten.setup({ cache_max_entries = 10, cache_ttl = 5 })
		local state = require("tungsten.state")
		local first_cache = state.cache
		tungsten.setup({ cache_max_entries = 20, cache_ttl = 15 })
		assert.are_not.equal(first_cache, state.cache)
		assert.are.equal(20, state.cache.max_entries)
		assert.are.equal(15, state.cache.ttl)
	end)
end)
