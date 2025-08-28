-- Tests ensuring point tuple grammar does not conflict with existing constructs

package.loaded["tungsten.core.registry"] = nil
package.loaded["tungsten.core.parser"] = nil
package.loaded["tungsten.core"] = nil
package.loaded["tungsten.domains.arithmetic"] = nil
package.loaded["tungsten.domains.calculus"] = nil
package.loaded["tungsten.domains.linear_algebra"] = nil
package.loaded["tungsten.domains.differential_equations"] = nil

local parser = require("tungsten.core.parser")
require("tungsten.core")
local ast = require("tungsten.core.ast")

local function parse_one(expr)
	local res = parser.parse(expr)
	if res and res.series and res.series[1] then
		return res.series[1]
	end
	return nil
end

describe("point grammar compatibility", function()
	it("keeps function applications as calls", function()
		local res = parser.parse("f(x,y)")
		assert.are.equal(1, #res.series)
		assert.are.same("function_call", res.series[1].type)
	end)

	it("nested commas inside functions do not split the top level", function()
		local res = parser.parse("g(1, h(2,3))")
		assert.are.equal(1, #res.series)
		local call = res.series[1]
		assert.are.same("function_call", call.type)
		assert.are.equal(2, #call.args)
		assert.are.same("function_call", call.args[2].type)
	end)

	it("does not treat command-prefixed parentheses as point tuples", function()
		local res = parser.parse("\\sin(x)")
		assert.are.equal(1, #res.series)
		assert.are.same("function_call", res.series[1].type)
	end)

	describe("arithmetic unaffected", function()
		it("parses mixed operations", function()
			local node = parse_one("1 + 2 * 3")
			local expected = ast.create_binary_operation_node(
				"+",
				{ type = "number", value = 1 },
				ast.create_binary_operation_node("*", { type = "number", value = 2 }, { type = "number", value = 3 })
			)
			assert.are.same(expected, node)
		end)

		it("parses parenthesized expressions", function()
			local node = parse_one("(4 - 5) / 6")
			local expected = ast.create_binary_operation_node(
				"/",
				ast.create_binary_operation_node("-", { type = "number", value = 4 }, { type = "number", value = 5 }),
				{ type = "number", value = 6 }
			)
			assert.are.same(expected, node)
		end)
	end)
end)
