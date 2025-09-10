-- Tests for parsing point literals (Point2 and Point3)

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

describe("point literal parsing", function()
	it("parses 2D point literals", function()
		local res = parser.parse("(x, y)")
		assert.are.equal(1, #res.series)
		local node = res.series[1]
		assert.are.same("Point2", node.type)
		assert.are.same("variable", node.x.type)
		assert.are.same("variable", node.y.type)
	end)

	it("parses 3D point literals", function()
		local res = parser.parse("(x, y, z)")
		assert.are.equal(1, #res.series)
		local node = res.series[1]
		assert.are.same("Point3", node.type)
		assert.are.same("variable", node.x.type)
		assert.are.same("variable", node.y.type)
		assert.are.same("variable", node.z.type)
	end)

	it("handles nested expressions inside points", function()
		local res = parser.parse("(x, y + g(1,2))")
		local node = res.series[1]
		assert.are.same("Point2", node.type)
		assert.are.same("binary", node.y.type)
	end)

	it("errors on invalid arity", function()
		local ast, err = parser.parse("(x, y, z, w)")
		assert.is_nil(ast)
		assert.is_truthy(err:match("Point tuples support only 2D or 3D"))
	end)

	it("does not misinterpret function calls as points", function()
		local res = parser.parse("f(x, y)")
		assert.are.equal(1, #res.series)
		assert.are.same("function_call", res.series[1].type)
	end)

	it("parses parametric tuples in advanced mode", function()
		local res = parser.parse("(sin(t),cos(t))", { mode = "advanced", form = "parametric" })
		local canonical = ast.canonical(res.series[1])
		assert.are.equal("Parametric2D(sin(t),cos(t))", canonical)
	end)

	it("treats variable tuples as Point2 in parametric mode", function()
		local res = parser.parse("(x, y)", { mode = "advanced", form = "parametric" })
		local node = res.series[1]
		assert.are.same("Point2", node.type)
	end)

	it("parses function tuples with shared parameter as Parametric2D", function()
		local res = parser.parse("(f(t), g(t))", { mode = "advanced", form = "parametric" })
		local canonical = ast.canonical(res.series[1])
		assert.are.equal("Parametric2D(f(t),g(t))", canonical)
	end)

	it("errors on polar tuples with non-theta second element", function()
		local node, err = parser.parse("(r(phi), phi)", { mode = "advanced", form = "polar" })
		assert.is_nil(node)
		assert.is_truthy(err:match("Polar tuples must have theta as second element"))
	end)

	it("errors when r is not a function of theta in polar tuples", function()
		local node, err = parser.parse("(r(t), \\theta)", { mode = "advanced", form = "polar" })
		assert.is_nil(node)
		assert.is_truthy(err:match("Polar tuples must define r as a function of θ"))
	end)

	it("parses polar tuples with greek theta", function()
		local res = parser.parse("(r(\\theta), \\theta)", { form = "polar" })
		local node = res.series[1]
		assert.are.same("Polar2D", node.type)
		assert.are.same("greek", node.r.args[1].type)
		assert.are.same("theta", node.r.args[1].name)
	end)

	it("errors when theta is used without polar form", function()
		local node, err = parser.parse("(r, \\theta)")
		assert.is_nil(node)
		assert.is_truthy(err:match("theta") and err:match("polar"))
	end)

	it("treats numeric tuples as Point2 in parametric mode", function()
		local res = parser.parse("(1,2)", { mode = "advanced", form = "parametric" })
		local node = res.series[1]
		assert.are.same("Point2", node.type)
		assert.are.same("number", node.x.type)
		assert.are.same("number", node.y.type)
	end)
end)
