local guard = require("tungsten.backends.python.analyzers.special_function_guard")

describe("python special function guard", function()
	it("identifies special functions and normalizes names", function()
		assert.is_false(guard.is_special_function(42))
		assert.is_true(guard.is_special_function("BESSELJ"))
	end)

	it("checks numpy support rules", function()
		assert.is_true(guard.is_numpy_supported(nil))
		assert.is_true(guard.is_numpy_supported("custom_func"))
		assert.is_false(guard.is_numpy_supported("gamma"))
		assert.is_true(guard.is_numpy_supported("Erf"))
	end)

	it("finds disallowed functions from different ast node shapes", function()
		local direct = {
			type = "function_call",
			name_node = { name = "bessely" },
		}
		assert.equals("bessely", guard.find_disallowed_special_function(direct))

		local nested = {
			type = "root",
			harmless = { type = "function_call", name_node = { other = true } },
			suspicious = { type = "function_call", name_node = "raw_value", name = "lambertw" },
		}
		assert.equals("lambertw", guard.find_disallowed_special_function(nested))
	end)
end)
