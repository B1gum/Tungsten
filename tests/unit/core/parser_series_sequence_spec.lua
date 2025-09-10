-- Tests for parser entrypoint handling of series and sequences

package.loaded["tungsten.core.registry"] = nil
package.loaded["tungsten.core.parser"] = nil
package.loaded["tungsten.core"] = nil
package.loaded["tungsten.domains.arithmetic"] = nil
package.loaded["tungsten.domains.calculus"] = nil
package.loaded["tungsten.domains.linear_algebra"] = nil
package.loaded["tungsten.domains.differential_equations"] = nil

local parser = require("tungsten.core.parser")
require("tungsten.core")

describe("parser series and sequence handling", function()
	it("creates a Sequence node for top-level commas", function()
		local res = parser.parse("sin(x), cos(x)")
		assert.are.equal(1, #res.series)
		local seq = res.series[1]
		assert.are.same("Sequence", seq.type)
		assert.are.equal(2, #seq.nodes)
		assert.are.same("function_call", seq.nodes[1].type)
		assert.are.same("function_call", seq.nodes[2].type)
	end)

	it("splits input into multiple series by semicolon or newline", function()
		local res = parser.parse("(1,2); (3,4)\n x^2 + y^2 = 1")
		assert.are.equal(3, #res.series)
		assert.are.same("Point2", res.series[1].type)
		assert.are.same("Point2", res.series[2].type)
		local third = res.series[3]
		assert.are.same("Equality", third.type)
		assert.are.equal("binary", third.lhs.type)
	end)

	it("does not treat function calls as points", function()
		local res = parser.parse("f(x,y)")
		assert.are.equal(1, #res.series)
		assert.are.same("function_call", res.series[1].type)
	end)

	it("ignores nested commas inside delimiters", function()
		local res = parser.parse("g(1, h(2,3)), 4")
		assert.are.equal(1, #res.series)
		local seq = res.series[1]
		assert.are.same("Sequence", seq.type)
		assert.are.equal(2, #seq.nodes)
		assert.are.same("function_call", seq.nodes[1].type)
		assert.are.same("number", seq.nodes[2].type)
	end)

	it("respects \\left...\\right delimiters", function()
		local res = parser.parse("\\left(1,2\\right), \\left(3,4\\right)")
		assert.are.equal(1, #res.series)
		local seq = res.series[1]
		assert.are.same("Sequence", seq.type)
		assert.are.equal(2, #seq.nodes)
		assert.are.same("Point2", seq.nodes[1].type)
		assert.are.same("Point2", seq.nodes[2].type)
	end)

	it("respects delimiter commands inside \\left...\\right", function()
		local res = parser.parse("\\left\\langle a,b \\right\\rangle, c")
		assert.are.equal(1, #res.series)
		local seq = res.series[1]
		assert.are.same("Sequence", seq.type)
		assert.are.equal(2, #seq.nodes)
	end)

	it("handles '.' and '|' delimiters in \\left...\\right", function()
		local tls_name, tls = debug.getupvalue(parser.parse, 4)
		assert.are.equal("top_level_split", tls_name)
		local parts = tls("\\left.1,2\\right|, 3", { [","] = true })
		assert.are.equal(2, #parts)
		assert.are.same("\\left1,2\\right|", parts[1].str)
		assert.are.same(" 3", parts[2].str)
	end)

	it("treats numeric function call tuples as Point2 in parametric mode", function()
		local res = parser.parse("(sin(1), cos(1))", { mode = "advanced", form = "parametric" })
		assert.are.equal(1, #res.series)
		local node = res.series[1]
		assert.are.same("Point2", node.type)
		assert.are.same("function_call", node.x.type)
		assert.are.same("function_call", node.y.type)
	end)

	it("treats tuples with greek variable as Parametric2D in parametric mode", function()
		local res = parser.parse("(1, \\theta)", { mode = "advanced", form = "parametric" })
		assert.are.equal(1, #res.series)
		local node = res.series[1]
		assert.are.same("Parametric2D", node.type)
		assert.are.same("number", node.x.type)
		assert.are.same("greek", node.y.type)
		assert.are.same("theta", node.y.name)
	end)

	it("does not split at commas within non-letter macros", function()
		local res = parser.parse("x\\,y")
		assert.is_not_nil(res)
		assert.are.equal(1, #res.series)
		assert.are_not.equal("Sequence", res.series[1].type)
	end)
end)
