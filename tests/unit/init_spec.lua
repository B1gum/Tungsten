local mock_utils = require("tests.helpers.mock_utils")

describe("tungsten.init", function()
	local tungsten

	local function reset_modules(extra)
		local modules = {
			"tungsten",
			"tungsten.init",
			"tungsten.core.domain_manager",
			"tungsten.util.logger",
			"tungsten.state",
			"tungsten.core.registry",
			"tungsten.core.commands",
			"tungsten.ui.which_key",
			"tungsten.ui.commands",
			"tungsten.ui",
			"tungsten.core",
			"tungsten.backends.manager",
		}
		if type(extra) == "table" then
			for _, name in ipairs(extra) do
				table.insert(modules, name)
			end
		end
		mock_utils.reset_modules(modules)
	end

	local function stub_setup_dependencies()
		package.loaded["tungsten.core.domain_manager"] = {
			register_domain = function() end,
		}
		package.loaded["tungsten.util.logger"] = {
			set_level = function() end,
		}
		package.loaded["tungsten.state"] = {
			persistent_variables = {},
			active_jobs = {},
		}
		package.loaded["tungsten.core.registry"] = { commands = {} }
		package.loaded["tungsten.core.commands"] = {}
		package.loaded["tungsten.ui.which_key"] = {}
		package.loaded["tungsten.ui.commands"] = {}
		package.loaded["tungsten.ui"] = {}
		package.loaded["tungsten.core"] = {}
	end

	before_each(function()
		reset_modules()
		stub_setup_dependencies()
		tungsten = require("tungsten")
	end)

	after_each(function()
		package.preload["tungsten.backends.autoload"] = nil
		package.loaded["tungsten.backends.autoload"] = nil
		reset_modules()
	end)

	it("loads the configured backend module before activation", function()
		local backend_manager = require("tungsten.backends.manager")
		local backend = { load_handlers = function() end }
		backend.activate = function(opts)
			backend.opts = opts
			return backend
		end
		package.preload["tungsten.backends.autoload"] = function()
			backend.was_required = true
			backend_manager.register("autoload", backend)
			return backend
		end

		tungsten.setup({
			backend = "autoload",
			backend_opts = {
				autoload = { foo = 42 },
			},
		})

		assert.is_true(backend.was_required)
		assert.are.same({ foo = 42 }, backend.opts)
		assert.are.equal(backend, backend_manager.current())
	end)

	it("raises a descriptive error when the backend module cannot be loaded", function()
		local ok, err = pcall(function()
			tungsten.setup({
				backend = "missing-backend",
				backend_opts = {},
			})
		end)
		assert.is_false(ok)
		assert.is_truthy(err:match("failed to activate backend 'missing%-backend'"), err)
	end)
end)
