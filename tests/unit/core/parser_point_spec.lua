-- Tests for parsing point literals (Point2 and Point3)

package.loaded["tungsten.core.registry"] = nil
package.loaded["tungsten.core.parser"] = nil
package.loaded["tungsten.core"] = nil
package.loaded["tungsten.domains.arithmetic"] = nil
package.loaded["tungsten.domains.calculus"] = nil
package.loaded["tungsten.domains.linear_algebra"] = nil
package.loaded["tungsten.domains.differential_equations"] = nil

local parser = require("tungsten.core.parser")
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
end)
