-- Tests for canonical AST debug strings from parser

package.loaded["tungsten.core.registry"] = nil
package.loaded["tungsten.core.parser"] = nil
package.loaded["tungsten.core"] = nil
package.loaded["tungsten.domains.arithmetic"] = nil
package.loaded["tungsten.domains.calculus"] = nil
package.loaded["tungsten.domains.linear_algebra"] = nil
package.loaded["tungsten.domains.differential_equations"] = nil

local parser = require("tungsten.core.parser")
local ast = require("tungsten.core.ast")
require("tungsten.core")

describe("parser canonical debug strings", function()
	it("parses top-level sequence", function()
		local res = parser.parse("sin(x), cos(x)")
		assert.are.equal(1, #res.series)
		local str = ast.canonical(res.series[1])
		assert.are.equal("Sequence(sin(x),cos(x))", str)
	end)

	it("splits semicolon-separated series", function()
		local res = parser.parse("(1,2); (3,4)")
		assert.are.equal(2, #res.series)
		assert.are.equal("Point2(1,2)", ast.canonical(res.series[1]))
		assert.are.equal("Point2(3,4)", ast.canonical(res.series[2]))
	end)

	it("handles nested expressions inside points", function()
		local res = parser.parse("(x, y+g(1,2))")
		local str = ast.canonical(res.series[1])
		assert.are.equal("Point2(x,binary{left=y,operator=+,right=g(1,2)})", str)
	end)

	it("produces equality canonical form", function()
		local res = parser.parse("x^2 + y^2 = 1")
		local str = ast.canonical(res.series[1])
		assert.are.equal(
			"Equality(binary{left=superscript{base=x,exponent=2},operator=+,right=superscript{base=y,exponent=2}},1)",
			str
		)
	end)

	it("produces inequality canonical form", function()
		local res = parser.parse([[y \le x]])
		local str = ast.canonical(res.series[1])
		assert.are.equal("Inequality(≤,y,x)", str)
	end)

	it("produces inequality canonical form with unicode symbol", function()
		local res = parser.parse("y ≤ x")
		assert.are.equal("Inequality(≤,y,x)", ast.canonical(res.series[1]))
	end)

	it("produces inequality canonical form with alignment marker", function()
		local res = parser.parse([[x & \leq y]])
		assert.are.equal("Inequality(≤,x,y)", ast.canonical(res.series[1]))
	end)

	it("errors on chained inequalities", function()
		local res, err = parser.parse("a < b < c")
		assert.is_nil(res)
		assert.matches("Chained inequalities are not supported", err)
	end)

	it("errors on invalid point arity", function()
		local res, err = parser.parse("(x, y, z, w)")
		assert.is_nil(res)
		assert.matches("Point tuples support only 2D or 3D", err)
	end)

	it("ignores commas inside delimiters", function()
		local res = parser.parse("g(1, h(2,3)), 4")
		assert.are.equal(1, #res.series)
		local str = ast.canonical(res.series[1])
		assert.are.equal("Sequence(g(1,h(2,3)),4)", str)
	end)

	it("does not misinterpret function calls as points", function()
		local res = parser.parse("f(x,y)")
		assert.are.equal(1, #res.series)
		assert.are.same("function_call", res.series[1].type)
	end)
end)
