local mock_utils = require("tests.helpers.mock_utils")

describe("backends.manager", function()
	local manager

	before_each(function()
		mock_utils.reset_modules({ "tungsten.backends.manager" })
		manager = require("tungsten.backends.manager")
	end)

	it("registers and activates a backend module", function()
		local backend = {}
		backend.activate = function(opts)
			backend.called_opts = opts
			return backend
		end
		manager.register("demo", backend)
		local inst, err = manager.activate("demo", { foo = 42 })
		assert.is_nil(err)
		assert.are.equal(backend, inst)
		assert.are.same({ foo = 42 }, backend.called_opts)
		assert.are.equal(backend, manager.current())
	end)

	it("returns an error for unknown backend", function()
		local inst, err = manager.activate("missing")
		assert.is_nil(inst)
		assert.is_string(err)
	end)

	it("switches active backend", function()
		local a = {}
		local b = {}
		manager.register("a", a)
		manager.register("b", b)
		manager.activate("a")
		assert.are.equal(a, manager.current())
		manager.activate("b")
		assert.are.equal(b, manager.current())
	end)
end)
