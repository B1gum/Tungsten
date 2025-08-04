-- tests/unit/backends/python/arithmetic_spec.lua

local spy = require("luassert.spy")
local python_handlers = require("tungsten.backends.python.domains.arithmetic")

describe("Tungsten Arithmetic Python Handlers", function()
	local handlers = python_handlers.handlers
	local mock_recur_render

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
	end)

	describe("sqrt handler", function()
		it("renders square root", function()
			local node = {
				type = "sqrt",
				radicand = { type = "variable", name = "x" },
			}
			assert.are.equal("sp.sqrt(x)", handlers.sqrt(node, mock_recur_render))
		end)
	end)

	describe("function_call handler", function()
		it("renders function call", function()
			local node = {
				type = "function_call",
				name_node = { type = "variable", name = "sin" },
				args = { { type = "variable", name = "x" } },
			}
			assert.are.equal("sin(x)", handlers.function_call(node, mock_recur_render))
		end)
	end)
end)
