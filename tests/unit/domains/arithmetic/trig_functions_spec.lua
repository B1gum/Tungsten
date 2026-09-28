package.loaded["tungsten.core.registry"] = nil
package.loaded["tungsten.core.parser"] = nil
package.loaded["tungsten.core"] = nil
package.loaded["tungsten.domains.arithmetic"] = nil

local parser = require("tungsten.core.parser")
require("tungsten.core")

local function parse_one(input)
	local parsed = parser.parse(input)
	return parsed and parsed.series and parsed.series[1] or nil
end

local function assert_function_call(input, name, arg_name)
	local node = parse_one(input)
	assert.is_not_nil(node)
	assert.are.equal("function_call", node.type)
	assert.are.equal(name, node.name_node.name)
	assert.are.equal(1, #node.args)
	assert.are.equal(arg_name, node.args[1].name)
end

describe("arithmetic trigonometric function parsing", function()
	it("parses hyperbolic trig commands as complete commands", function()
		assert_function_call("\\sinh(x)", "sinh", "x")
		assert_function_call("\\cosh x", "cosh", "x")
		assert_function_call("\\tanh{x}", "tanh", "x")
	end)

	it("registers cot, sec, and csc", function()
		assert_function_call("\\cot(x)", "cot", "x")
		assert_function_call("\\sec(x)", "sec", "x")
		assert_function_call("\\csc(x)", "csc", "x")
	end)

	it("does not parse the sin prefix of sinh", function()
		local node = parse_one("\\sinh(x)")
		assert.are.equal("sinh", node.name_node.name)
	end)
end)
