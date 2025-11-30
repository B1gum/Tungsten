local mock_utils = require("tests.helpers.mock_utils")

describe("backends.util", function()
	local util

	before_each(function()
		mock_utils.reset_modules({ "tungsten.backends.util" })
		util = require("tungsten.backends.util")
	end)

	describe("should_wrap_in_parens", function()
		local base_op = { prec = 1, assoc = "L" }

		it("skips wrapping when parent or child is missing", function()
			assert.is_false(util.should_wrap_in_parens(nil, {}, {}, true))
			assert.is_false(util.should_wrap_in_parens(base_op, { type = "number" }, {}, true))
		end)

		it("wraps unknown operators and lower precedence children", function()
			local child = { type = "binary", operator = "*" }
			assert.is_true(util.should_wrap_in_parens(base_op, child, {}, true))

			assert.is_true(util.should_wrap_in_parens(base_op, child, { ["*"] = { prec = 0 } }, true))
			assert.is_false(util.should_wrap_in_parens(base_op, child, { ["*"] = { prec = 2 } }, true))
		end)

		it("respects associativity at matching precedence", function()
			local child = { type = "binary", operator = "+" }

			local parent_non = { prec = 1, assoc = "N" }
			assert.is_true(util.should_wrap_in_parens(parent_non, child, { ["+"] = { prec = 1, assoc = "L" } }, true))

			local parent_right = { prec = 1, assoc = "R" }
			assert.is_true(util.should_wrap_in_parens(parent_right, child, { ["+"] = { prec = 1, assoc = "L" } }, true))
			assert.is_false(util.should_wrap_in_parens(parent_right, child, { ["+"] = { prec = 1, assoc = "L" } }, false))

			local parent_left = { prec = 1, assoc = "L" }
			assert.is_false(util.should_wrap_in_parens(parent_left, child, { ["+"] = { prec = 1, assoc = "L" } }, true))
			assert.is_true(util.should_wrap_in_parens(parent_left, child, { ["+"] = { prec = 1, assoc = "L" } }, false))
		end)
	end)

	it("maps renders and handles nil lists", function()
		local calls = {}
		local rendered = util.map_render({ 1, 2, 3 }, function(node)
			table.insert(calls, node)
			return node * 2
		end)

		assert.same({ 1, 2, 3 }, calls)
		assert.same({ 2, 4, 6 }, rendered)

		assert.same({}, util.map_render(nil, function() end))
	end)

	it("renders requested fields using provided callback", function()
		local node = { left = "a", right = "b" }
		local mt = getmetatable("")
		local original = mt.__index.table
		mt.__index.table = mt.__index.table or table
		local first, second = util.render_fields(node, { "left", "right" }, function(value)
			return value .. value
		end)

		assert.equals("aa", first)
		assert.equals("bb", second)

		mt.__index.table = original
	end)
end)
