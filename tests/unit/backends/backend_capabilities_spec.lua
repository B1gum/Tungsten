-- Unit tests for backend plotting capabilities and error handling.
local backends = require("tungsten.domains.plotting.backends")

describe("backend capabilities", function()
	it("returns capabilities for each backend", function()
		local wolfram = backends.get_backend("wolfram")
		assert.is_truthy(wolfram)
		assert.is_true(wolfram.supports.explicit[2])
		assert.is_true(wolfram.supports.parametric[3])
                assert.is_true(wolfram.inequalities[2])
                assert.is_true(wolfram.points[2])

		local python = backends.get_backend("python")
		assert.is_truthy(python)
		assert.is_true(python.supports.explicit[2])
		assert.is_false(backends.is_supported("python", "implicit", 3))
                assert.is_nil(python.inequalities[2])
                assert.is_true(python.points[2])
	end)

	it("checks support correctly", function()
		assert.is_true(backends.is_supported("wolfram", "implicit", 3))
		assert.is_true(backends.is_supported("python", "explicit", 2))
		assert.is_false(backends.is_supported("python", "implicit", 3))
		assert.is_false(backends.is_supported("python", "unknown", 2))
		assert.is_true(backends.is_supported("wolfram", "implicit", 2, { inequalities = true }))
		assert.is_false(backends.is_supported("python", "implicit", 2, { inequalities = true }))
                assert.is_true(backends.is_supported("wolfram", "explicit", 2, { points = true }))
                assert.is_true(backends.is_supported("python", "explicit", 2, { points = true }))
	end)

	it("flags python explicit x functions as unsupported", function()
		assert.is_false(backends.is_supported("python", "explicit", 2, { dependent_vars = { "x" } }))
	end)

	it("uses wolfram as default backend", function()
		local original = _G.require
		_G.require = function(name)
			if name == "tungsten.config" then
				return {}
			end
			return original(name)
		end
		local backend = backends.get_configured_backend()
		_G.require = original
		assert.are.equal("wolfram", backend.name)
	end)
end)
