-- tests/unit/backends/python/arithmetic_spec.lua

local spy = require("luassert.spy")
local stub = require("luassert.stub")
local config = require("tungsten.config")
local logger = require("tungsten.util.logger")
local python_handlers = require("tungsten.backends.python.domains.arithmetic")

describe("Tungsten Arithmetic Python Handlers", function()
	local handlers = python_handlers.handlers
	local mock_recur_render
	local original_backend_opts

	before_each(function()
		mock_recur_render = spy.new(function(child_node)
			if child_node.type == "number" then
				return tostring(child_node.value)
			end
			if child_node.type == "variable" then
				return child_node.name
			end
			if child_node.type == "binary" then
				local left_rendered = mock_recur_render(child_node.left)
				local right_rendered = mock_recur_render(child_node.right)
				if child_node.operator == "^" then
					return "(" .. left_rendered .. ") ** (" .. right_rendered .. ")"
				end
				return left_rendered .. " " .. child_node.operator .. " " .. right_rendered
			end
			return "mock(" .. child_node.type .. ")"
		end)
		original_backend_opts = config.backend_opts
	end)

	after_each(function()
		config.backend_opts = original_backend_opts
	end)

	describe("number handler", function()
		it("converts number node to string", function()
			local node = { type = "number", value = 42 }
			assert.are.equal("42", handlers.number(node, mock_recur_render))
		end)
	end)

	describe("variable handler", function()
		it("converts variable node to its name", function()
			local node = { type = "variable", name = "x" }
			assert.are.equal("x", handlers.variable(node, mock_recur_render))
		end)
	end)

	describe("binary handler", function()
		it("renders a + b", function()
			local node = {
				type = "binary",
				operator = "+",
				left = { type = "variable", name = "a" },
				right = { type = "variable", name = "b" },
			}
			assert.are.equal("a + b", handlers.binary(node, mock_recur_render))
		end)

		it("renders a ^ b as power", function()
			local node = {
				type = "binary",
				operator = "^",
				left = { type = "variable", name = "a" },
				right = { type = "number", value = 2 },
			}
			assert.are.equal("(a) ** (2)", handlers.binary(node, mock_recur_render))
		end)

		it("warns and renders unknown operator without precedence", function()
			local warn_stub = stub(logger, "warn")
			local node = {
				type = "binary",
				operator = "??",
				left = { type = "variable", name = "x" },
				right = { type = "variable", name = "y" },
			}

			local result = handlers.binary(node, mock_recur_render)

			assert.are.equal("x ?? y", result)
			assert.spy(warn_stub).was.called(1)
			warn_stub:revert()
		end)

		it("wraps children in parentheses based on precedence", function()
			local node = {
				type = "binary",
				operator = "*",
				left = {
					type = "binary",
					operator = "+",
					left = { type = "variable", name = "a" },
					right = { type = "variable", name = "b" },
				},
				right = {
					type = "binary",
					operator = "*",
					left = { type = "variable", name = "c" },
					right = { type = "variable", name = "d" },
				},
			}

			assert.are.equal("(a + b) * (c * d)", handlers.binary(node, mock_recur_render))
		end)

		it("renders equality comparisons with Eq", function()
			local node = {
				type = "binary",
				operator = "==",
				left = { type = "number", value = 1 },
				right = { type = "number", value = 2 },
			}

			assert.are.equal("sp.Eq(1, 2)", handlers.binary(node, mock_recur_render))
		end)
	end)

	describe("sqrt handler", function()
		it("renders square root", function()
			local node = {
				type = "sqrt",
				radicand = { type = "variable", name = "x" },
			}
			assert.are.equal("sp.sqrt(x)", handlers.sqrt(node, mock_recur_render))
		end)

		it("renders nth root when index is provided", function()
			local node = {
				type = "sqrt",
				radicand = { type = "variable", name = "y" },
				index = { type = "number", value = 3 },
			}

			assert.are.equal("sp.root(y, 3)", handlers.sqrt(node, mock_recur_render))
		end)
	end)

	describe("function_call handler", function()
		it("renders function call", function()
			local node = {
				type = "function_call",
				name_node = { type = "variable", name = "sin" },
				args = { { type = "variable", name = "x" } },
			}
			assert.are.equal("sp.sin(x)", handlers.function_call(node, mock_recur_render))
		end)

		it("maps function names using python backend opts", function()
			config.backend_opts = {
				python = {
					function_mappings = {
						sin = "math_sin",
					},
				},
			}

			local node = {
				type = "function_call",
				name_node = { type = "variable", name = "Sin" },
				args = { { type = "variable", name = "x" }, { type = "number", value = 1 } },
			}

			assert.are.equal("math_sin(x, 1)", handlers.function_call(node, mock_recur_render))
		end)
	end)

	describe("constant handler", function()
		it("uses python representation for known constants", function()
			local node = { type = "constant", name = "pi" }
			assert.are.equal("sp.pi", handlers.constant(node))
		end)

		it("falls back to tostring for unknown constants", function()
			local node = { type = "constant", name = "CustomConstant" }
			assert.are.equal("CustomConstant", handlers.constant(node))
		end)
	end)

	describe("fraction handler", function()
		it("renders numerator and denominator with parentheses", function()
			local node = {
				type = "fraction",
				numerator = { type = "variable", name = "a" },
				denominator = { type = "variable", name = "b" },
			}

			assert.are.equal("(a) / (b)", handlers.fraction(node, mock_recur_render))
		end)
	end)

	describe("superscript handler", function()
		it("renders exponentiation with parentheses", function()
			local node = {
				type = "superscript",
				base = { type = "variable", name = "x" },
				exponent = { type = "number", value = 3 },
			}

			assert.are.equal("(x) ** (3)", handlers.superscript(node, mock_recur_render))
		end)
	end)

	describe("subscript handler", function()
		it("renders symbol with subscript", function()
			local node = {
				type = "subscript",
				base = { type = "variable", name = "a" },
				subscript = { type = "number", value = 1 },
			}

			assert.are.equal("Symbol('a_1')", handlers.subscript(node, mock_recur_render))
		end)
	end)

	describe("unary handler", function()
		it("wraps negated binary operands in parentheses", function()
			local node = {
				type = "unary",
				operator = "-",
				value = {
					type = "binary",
					operator = "+",
					left = { type = "variable", name = "x" },
					right = { type = "variable", name = "y" },
				},
			}

			assert.are.equal("(-(x + y))", handlers.unary(node, mock_recur_render))
		end)

		it("prefixes non-binary operands directly", function()
			local node = {
				type = "unary",
				operator = "-",
				value = { type = "number", value = 5 },
			}

			assert.are.equal("(-5)", handlers.unary(node, mock_recur_render))
		end)

		it("renders other unary operators without wrapping", function()
			local node = {
				type = "unary",
				operator = "+",
				value = { type = "variable", name = "z" },
			}

			assert.are.equal("+z", handlers.unary(node, mock_recur_render))
		end)
	end)

	describe("solve_system handler", function()
		it("renders equations and variables lists", function()
			local node = {
				type = "solve_system",
				equations = {
					{
						type = "binary",
						operator = "==",
						left = { type = "variable", name = "x" },
						right = { type = "number", value = 1 },
					},
					{
						type = "binary",
						operator = "==",
						left = { type = "variable", name = "y" },
						right = { type = "number", value = 2 },
					},
				},
				variables = {
					{ type = "variable", name = "x" },
					{ type = "variable", name = "y" },
				},
			}

			assert.are.equal("sp.solve([x == 1, y == 2], [x, y])", handlers.solve_system(node, mock_recur_render))
		end)
	end)
end)
