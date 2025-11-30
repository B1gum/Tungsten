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

	it("throws descriptive errors for invalid registrations", function()
		assert.has_error(function()
			manager.register(123, {})
		end, "Backend name must be a string")

		assert.has_error(function()
			manager.register("demo")
		end, "Backend module is nil")
	end)

	it("activates backends regardless of factory shape", function()
		local plain = { flag = "plain" }
		manager.register("plain", plain)

		local with_setup = {}
		with_setup.setup = function(opts)
			with_setup.opts = opts
		end
		manager.register("setup", with_setup)

		local with_new = {
			new = function(opts)
				return { created_with = opts }
			end,
		}
		manager.register("new", with_new)

		local factory_fn = function(opts)
			return { from_fn = opts }
		end
		manager.register("func", factory_fn)

		local inst_plain = assert(manager.activate("plain", { a = 1 }))
		assert.same(plain, inst_plain)

		local inst_setup = assert(manager.activate("setup", { b = 2 }))
		assert.same(with_setup, inst_setup)
		assert.same({ b = 2 }, with_setup.opts)

		local inst_new = assert(manager.activate("new", { c = 3 }))
		assert.same({ created_with = { c = 3 } }, inst_new)

		local inst_func = assert(manager.activate("func", { d = 4 }))
		assert.same({ from_fn = { d = 4 } }, inst_func)
	end)
end)
