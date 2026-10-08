local parser = require("tungsten.core.parser")
require("tungsten.core")
local ast = require("tungsten.core.ast")
local config = require("tungsten.config")
local functions = require("tungsten.core.function_definitions")

local function parse_one(text)
	local result, err = parser.parse(text)
	assert.is_not_nil(result, err)
	return result.series[1]
end

local function define(text)
	local definition, err = functions.parse_definition(text)
	assert.is_not_nil(definition, err)
	local ok, store_err = functions.store(definition)
	assert.is_true(ok, store_err)
end

describe("function definitions and implicit multiplication", function()
	local symbolic_functions
	before_each(function()
		functions.clear()
		symbolic_functions = config.symbolic_functions
	end)
	after_each(function()
		functions.clear()
		config.symbolic_functions = symbolic_functions
	end)

	it("treats undeclared scalar and Greek names before groups as multiplication", function()
		for _, text in ipairs({ "x(x+1)", "x (x+1)", "a(a+1)", "\\theta(\\theta+1)", "x\\left(x+1\\right)" }) do
			local result = parse_one(text)
			assert.equals("binary", result.type)
			assert.equals("*", result.operator)
		end
	end)

	it("parses the Collect example exactly like explicit multiplication", function()
		assert.are.same(parse_one("x \\cdot (x+1) + x \\cdot (x^2+3x)"), parse_one("x(x+1) + x(x^2+3x)"))
	end)

	it("preserves symbolic, built-in, and modified Bessel function calls", function()
		for _, text in ipairs({
			"f(x)",
			"g(x)",
			"h(x)",
			"r(x)",
			"sin(x)",
			"sin (x)",
			"\\sin(x)",
			"u(t)",
			"I_0(x)",
			"K_1(x)",
		}) do
			assert.equals("function_call", parse_one(text).type)
		end
	end)

	it("does not mistake a name starting with a built-in name for that function", function()
		assert.equals("binary", parse_one("sinus(x+1)").type)
	end)

	it("preserves ODE initial-condition calls without making scalar y globally callable", function()
		local result = parser.parse("y''+y=0; y(0)=1; y'(0)=0", { allow_multiple_relations = true })
		assert.equals("function_call", result.series[2].lhs.type)
		assert.equals("y", result.series[2].lhs.name_node.name)
		assert.equals("binary", parse_one("y(y+1)").type)
	end)

	it("expands f(5) to 5 squared without mutating the stored body", function()
		define("f(x) = x^2")
		local call = parse_one("f(5)")
		local expanded = functions.expand(call)
		assert.are.same(ast.create_superscript_node(ast.create_number_node(5), ast.create_number_node(2)), expanded)
		assert.equals("function_call", call.type)
		assert.are.same(parse_one("6^2"), functions.expand(parse_one("f(6)")))
	end)

	it("registers arbitrary names only after a definition is stored", function()
		assert.equals("binary", parse_one("square(t)").type)
		define("square(t) = t(t+1)")
		assert.equals("function_call", parse_one("square(5)").type)
		assert.are.same(parse_one("5*(5+1)"), functions.expand(parse_one("square(5)")))
		functions.clear()
		assert.equals("binary", parse_one("square(t)").type)
	end)

	it("renders an expanded call as arithmetic in both backends", function()
		define("f(x)=x^2")
		local expanded = functions.expand(parse_one("f(5)"))
		local render = require("tungsten.core.render").render
		local python = require("tungsten.backends.python.domains.arithmetic").handlers
		local wolfram = require("tungsten.backends.wolfram.domains.arithmetic").handlers
		assert.equals("(5) ** (2)", render(expanded, python))
		assert.equals("Power[5, 2]", render(expanded, wolfram))
	end)

	it("substitutes multiple arguments simultaneously", function()
		define("difference(x,y) := x-y")
		assert.are.same(parse_one("y-x"), functions.expand(parse_one("difference(y,x)")))
	end)

	it("treats formal parameters as scalars even when their names are symbolic functions", function()
		define("scale(f)=f(f+1)")
		assert.are.same(parse_one("5*(5+1)"), functions.expand(parse_one("scale(5)")))
	end)

	it("supports nested calls and redefinition", function()
		define("f(x)=x^2")
		assert.are.same(parse_one("(5^2)^2"), functions.expand(parse_one("f(f(5))")))
		define("g(t)=f(t)+1")
		assert.are.same(parse_one("5^2+1"), functions.expand(parse_one("g(5)")))
		define("f(x)=x+2")
		assert.are.same(parse_one("5+2+1"), functions.expand(parse_one("g(5)")))
	end)

	it("reports wrong arity instead of sending a malformed call to the backend", function()
		define("f(x)=x^2")
		local result, err = functions.expand(parse_one("f(1,2)"))
		assert.is_nil(result)
		assert.matches("Wrong number of arguments", err)
	end)

	it("rejects recursive definitions and preserves the previous definition", function()
		define("f(x)=x^2")
		local recursive = assert(functions.parse_definition("f(x)=f(x)+1"))
		local ok, err = functions.store(recursive)
		assert.is_nil(ok)
		assert.matches("Recursive", err)
		assert.are.same(parse_one("5^2"), functions.expand(parse_one("f(5)")))
	end)

	it("rejects indirect recursion", function()
		define("f(x)=g(x)")
		local recursive = assert(functions.parse_definition("g(x)=f(x)"))
		local ok, err = functions.store(recursive)
		assert.is_nil(ok)
		assert.matches("Recursive", err)
	end)

	it("keeps numeric function equations distinct from definitions", function()
		assert.is_nil(functions.parse_definition("f(5)=25"))
		assert.is_nil(functions.parse_definition("x(x+1)=3"))
	end)

	it("validates parameters, bodies, and built-in names", function()
		for _, text in ipairs({ "f(x,x)=x", "f(e)=e", "sin(x)=x", "f(x)=", "f(x)=x+", "f(x)=\\int x dx" }) do
			local definition, err = functions.parse_definition(text)
			assert.is_nil(definition)
			assert.is_not_nil(err)
		end
	end)

	it("allows a custom symbolic-function list, including an empty list", function()
		config.symbolic_functions = { "response" }
		assert.equals("function_call", parse_one("response(t)").type)
		assert.equals("binary", parse_one("f(x)").type)
		config.symbolic_functions = {}
		assert.equals("binary", parse_one("response(t)").type)
	end)
end)
