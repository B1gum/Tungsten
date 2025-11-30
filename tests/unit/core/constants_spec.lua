local constants = require("tungsten.core.constants")

describe("tungsten.core.constants", function()
	it("returns metadata for uppercase constant names", function()
		local lower_pi = constants.get("pi")
		local upper_pi = constants.get("PI")

		assert.is_table(lower_pi)
		assert.are.equal(lower_pi, upper_pi)
		assert.are.same({ python = "sp.pi", wolfram = "Pi" }, upper_pi)
		assert.is_true(constants.is_constant("PI"))
	end)

	it("returns nil for unknown constants", function()
		assert.is_nil(constants.get("unknown"))
		assert.is_false(constants.is_constant("unknown"))
	end)

	it("returns nil for non-string inputs", function()
		for _, input in ipairs({ nil, 123, {}, function() end }) do
			assert.is_nil(constants.get(input))
			assert.is_false(constants.is_constant(input))
		end
	end)
end)
