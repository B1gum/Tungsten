-- tests/unit/util/string_spec.lua

describe("util.string", function()
	local string_util = require("tungsten.util.string")

	describe("trim", function()
		it("should not change a string with no leading or trailing whitespace", function()
			assert.are.equal("hello", string_util.trim("hello"))
		end)

		it("should trim leading whitespace", function()
			assert.are.equal("hello", string_util.trim("  hello"))
		end)

		it("should trim trailing whitespace", function()
			assert.are.equal("hello", string_util.trim("hello  "))
		end)

		it("should trim both leading and trailing whitespace", function()
			assert.are.equal("hello world", string_util.trim("  hello world  "))
		end)

		it("should handle an empty string", function()
			assert.are.equal("", string_util.trim(""))
		end)

		it("should return an empty string if the input is only whitespace", function()
			assert.are.equal("", string_util.trim("   "))
		end)

		it("should not error on non-string inputs and return them as-is", function()
			assert.are.equal(nil, string_util.trim(nil))
			assert.are.equal(123, string_util.trim(123))

			local test_table = {}
			assert.are.equal(test_table, string_util.trim(test_table))
		end)
	end)
end)
