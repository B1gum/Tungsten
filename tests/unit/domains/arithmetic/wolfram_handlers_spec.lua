-- tests/unit/domains/arithmetic/wolfram_handlers_spec.lua

package.path = './lua/?.lua;./lua/?/init.lua;' .. package.path

local spy = require 'luassert.spy'
local stub = require 'luassert.stub'
local wolfram_handlers = require "tungsten.domains.arithmetic.wolfram_handlers"
local ast = require "tungsten.core.ast"

describe("Tungsten Arithmetic Wolfram Handlers", function()
  local handlers = wolfram_handlers.handlers
  local mock_recur_render
  local render_node_for_function_call

  before_each(function()
    mock_recur_render = spy.new(function(child_node)
      if child_node.type == "number" then return tostring(child_node.value) end
      if child_node.type == "variable" then return child_node.name end
      if child_node.type == "symbol" then return child_node.name end
      if child_node.type == "greek" then return child_node.name end
      if child_node.type == "binary" then
        local left_rendered = mock_recur_render(child_node.left)
        local right_rendered = mock_recur_render(child_node.right)
        return left_rendered .. child_node.operator .. right_rendered
      end
      return "mock_rendered(" .. child_node.type .. ")"
    end)

    render_node_for_function_call = function(node)
        return handlers.function_call(node, mock_recur_render)
    end
  end)

  describe("number handler", function()
    it("should convert an integer number node to its string representation", function()
      local node = { type = "number", value = 123 }
      assert.are.equal("123", handlers.number(node, mock_recur_render))
    end)

    it("should convert a floating-point number node to its string representation", function()
      local node = { type = "number", value = 1.23 }
      assert.are.equal("1.23", handlers.number(node, mock_recur_render))
    end)

    it("should convert zero to its string representation", function()
      local node = { type = "number", value = 0 }
      assert.are.equal("0", handlers.number(node, mock_recur_render))
    end)

    it("should convert a negative number to its string representation", function()
      local node = { type = "number", value = -456 }
      assert.are.equal("-456", handlers.number(node, mock_recur_render))
    end)
  end)

  describe("variable handler", function()
    it("should convert a variable node to its name", function()
      local node = { type = "variable", name = "x" }
      assert.are.equal("x", handlers.variable(node, mock_recur_render))
    end)

    it("should convert a multi-character variable node to its name", function()
      local node = { type = "variable", name = "longVar" }
      assert.are.equal("longVar", handlers.variable(node, mock_recur_render))
    end)
  end)

  describe("greek handler", function()
    it("should convert a greek letter node to its name", function()
      local node = { type = "greek", name = "alpha" }
      assert.are.equal("alpha", handlers.greek(node, mock_recur_render))
    end)

    it("should handle other greek letters", function()
      local node = { type = "greek", name = "Omega" }
      assert.are.equal("Omega", handlers.greek(node, mock_recur_render))
    end)
  end)

  describe("binary handler (bin_with_parens)", function()
    local prec = wolfram_handlers.precedence
    local function recur_render_for_binary(node)
      if node.type == "number" then return tostring(node.value) end
      if node.type == "variable" then return node.name end
      if node.type == "binary" then
        return handlers.binary(node, recur_render_for_binary)
      end
      return "mock_child_for_binary_test("..node.type..")"
    end

    it("should render a + b as 'a+b'", function()
      local node = { type = "binary", operator = "+", left = { type = "variable", name = "a" }, right = { type = "variable", name = "b" } }
      assert.are.equal("a+b", handlers.binary(node, recur_render_for_binary))
    end)

    it("should render a - b as 'a-b'", function()
      local node = { type = "binary", operator = "-", left = { type = "variable", name = "a" }, right = { type = "variable", name = "b" } }
      assert.are.equal("a-b", handlers.binary(node, recur_render_for_binary))
    end)

    it("should render a * b as 'a*b'", function()
      local node = { type = "binary", operator = "*", left = { type = "variable", name = "a" }, right = { type = "variable", name = "b" } }
      assert.are.equal("a*b", handlers.binary(node, recur_render_for_binary))
    end)

    it("should render a / b as 'a/b'", function()
      local node = { type = "binary", operator = "/", left = { type = "variable", name = "a" }, right = { type = "variable", name = "b" } }
      assert.are.equal("a/b", handlers.binary(node, recur_render_for_binary))
    end)

    it("a * (b + c) should be rendered as a*(b+c)", function()
      local node = {
        type = "binary", operator = "*",
        left = { type = "variable", name = "a" },
        right = { type = "binary", operator = "+", left = { type = "variable", name = "b" }, right = { type = "variable", name = "c" } }
      }
      assert.are.equal("a*(b+c)", handlers.binary(node, recur_render_for_binary))
    end)

    it("(a + b) * c should be rendered as (a+b)*c", function()
      local node = {
        type = "binary", operator = "*",
        left = { type = "binary", operator = "+", left = { type = "variable", name = "a" }, right = { type = "variable", name = "b" } },
        right = { type = "variable", name = "c" }
      }
      assert.are.equal("(a+b)*c", handlers.binary(node, recur_render_for_binary))
    end)

    it("a + b * c should be rendered as a+b*c (no parens for higher precedence child on right)", function()
      local node = {
        type = "binary", operator = "+",
        left = { type = "variable", name = "a" },
        right = { type = "binary", operator = "*", left = { type = "variable", name = "b" }, right = { type = "variable", name = "c" } }
      }
      assert.are.equal("a+b*c", handlers.binary(node, recur_render_for_binary))
    end)

    it("a * b + c should be rendered as a*b+c (no parens for higher precedence child on left)", function()
      local node = {
        type = "binary", operator = "+",
        left = { type = "binary", operator = "*", left = { type = "variable", name = "a" }, right = { type = "variable", name = "b" } },
        right = { type = "variable", name = "c" }
      }
      assert.are.equal("a*b+c", handlers.binary(node, recur_render_for_binary))
    end)

    it("a / (b + c) should be rendered as a/(b+c)", function()
      local node = {
        type = "binary", operator = "/",
        left = { type = "variable", name = "a" },
        right = { type = "binary", operator = "+", left = { type = "variable", name = "b" }, right = { type = "variable", name = "c" } }
      }
      assert.are.equal("a/(b+c)", handlers.binary(node, recur_render_for_binary))
    end)

    it("(a + b) / c should be rendered as (a+b)/c", function()
      local node = {
        type = "binary", operator = "/",
        left = { type = "binary", operator = "+", left = { type = "variable", name = "a" }, right = { type = "variable", name = "b" } },
        right = { type = "variable", name = "c" }
      }
      assert.are.equal("(a+b)/c", handlers.binary(node, recur_render_for_binary))
    end)

    it("a - (b + c) should be rendered as a-(b+c) for correctness", function()
      local node = {
        type = "binary", operator = "-",
        left = { type = "variable", name = "a" },
        right = { type = "binary", operator = "+", left = { type = "variable", name = "b" }, right = { type = "variable", name = "c" } }
      }
      assert.are.equal("a-(b+c)", handlers.binary(node, recur_render_for_binary))
    end)

    it("a - (b - c) should be rendered as a-(b-c) for correctness", function()
      local node = {
        type = "binary", operator = "-",
        left = { type = "variable", name = "a" },
        right = { type = "binary", operator = "-", left = { type = "variable", name = "b" }, right = { type = "variable", name = "c" } }
      }
      assert.are.equal("a-(b-c)", handlers.binary(node, recur_render_for_binary))
    end)

    it("a / (b * c) should be rendered as a/(b*c) (no parens for higher precedence child on right)", function()
      local node = {
        type = "binary", operator = "/",
        left = { type = "variable", name = "a" },
        right = { type = "binary", operator = "*", left = { type = "variable", name = "b" }, right = { type = "variable", name = "c" } }
      }
      assert.are.equal("a/(b*c)", handlers.binary(node, recur_render_for_binary))
    end)

    it("(a * b) / c should be rendered as (a*b)/c (no parens for higher precedence on left)", function()
      local node = {
        type = "binary", operator = "/",
        left = { type = "binary", operator = "*", left = { type = "variable", name = "a" }, right = { type = "variable", name = "b" } },
        right = { type = "variable", name = "c" }
      }
      assert.are.equal("a*b/c", handlers.binary(node, recur_render_for_binary))
    end)


    it("a ^ (b + c) should be rendered as a^(b+c)", function()
      local node = {
        type = "binary", operator = "^",
        left = { type = "variable", name = "a" },
        right = { type = "binary", operator = "+", left = { type = "variable", name = "b" }, right = { type = "variable", name = "c" } }
      }
      assert.are.equal("a^(b+c)", handlers.binary(node, recur_render_for_binary))
    end)

    it("(a + b) ^ c should be rendered as (a+b)^c", function()
      local node = {
        type = "binary", operator = "^",
        left = { type = "binary", operator = "+", left = { type = "variable", name = "a" }, right = { type = "variable", name = "b" } },
        right = { type = "variable", name = "c" }
      }
      assert.are.equal("(a+b)^c", handlers.binary(node, recur_render_for_binary))
    end)
  end)

  describe("fraction handler", function()
    it("should render a fraction node correctly", function()
      local node = {
        type = "fraction",
        numerator = { type = "number", value = 1 },
        denominator = { type = "variable", name = "n" }
      }
      assert.are.equal("(1)/(n)", handlers.fraction(node, mock_recur_render))
      assert.spy(mock_recur_render).was.called_with(node.numerator)
      assert.spy(mock_recur_render).was.called_with(node.denominator)
    end)

    it("should render a fraction with complex numerator and denominator", function()
      local node = {
        type = "fraction",
        numerator = { type = "binary", operator = "+", left = { type = "variable", name = "a"}, right = { type = "number", value = 1 }},
        denominator = { type = "sqrt", radicand = {type = "variable", name = "x"}}
      }
      assert.are.equal("(a+1)/(mock_rendered(sqrt))", handlers.fraction(node, mock_recur_render))
    end)
  end)

  describe("sqrt handler", function()
    it("should render a sqrt node without index correctly", function()
      local node = { type = "sqrt", radicand = { type = "variable", name = "x" } }
      assert.are.equal("Sqrt[x]", handlers.sqrt(node, mock_recur_render))
      assert.spy(mock_recur_render).was.called_with(node.radicand)
    end)

    it("should render a sqrt node with index correctly (Surd)", function()
      local node = {
        type = "sqrt",
        index = { type = "number", value = 3 },
        radicand = { type = "variable", name = "y" }
      }
      assert.are.equal("Surd[y,3]", handlers.sqrt(node, mock_recur_render))
      assert.spy(mock_recur_render).was.called_with(node.radicand)
      assert.spy(mock_recur_render).was.called_with(node.index)
    end)

     it("should render a sqrt node with complex radicand", function()
      local node = {
        type = "sqrt",
        radicand = { type = "fraction", numerator = { type = "number", value = 1}, denominator = {type = "variable", name = "x"}}
      }
      assert.are.equal("Sqrt[mock_rendered(fraction)]", handlers.sqrt(node, mock_recur_render))
    end)
  end)

  describe("superscript handler", function()
    it("should render base^exponent for variable base", function()
      local node = {
        type = "superscript",
        base = { type = "variable", name = "x" },
        exponent = { type = "number", value = 2 }
      }
      assert.are.equal("x^2", handlers.superscript(node, mock_recur_render))
      assert.spy(mock_recur_render).was.called_with(node.base)
      assert.spy(mock_recur_render).was.called_with(node.exponent)
    end)

    it("should render base^exponent for number base", function()
      local node = {
        type = "superscript",
        base = { type = "number", value = 10 },
        exponent = { type = "variable", name = "n" }
      }
      assert.are.equal("10^n", handlers.superscript(node, mock_recur_render))
    end)

    it("should render Power[base,exponent] for complex base (e.g. binary)", function()
      local node = {
        type = "superscript",
        base = { type = "binary", operator = "+", left = {type="variable", name="a"}, right={type="variable", name="b"}},
        exponent = { type = "number", value = 3 }
      }
      assert.are.equal("Power[a+b,3]", handlers.superscript(node, mock_recur_render))
    end)

    it("should render Power[base,exponent] for complex base (e.g. fraction)", function()
      local node = {
        type = "superscript",
        base = { type = "fraction", numerator = {type="variable", name="a"}, denominator={type="variable", name="b"}},
        exponent = { type = "variable", name = "x" }
      }
      assert.are.equal("Power[mock_rendered(fraction),x]", handlers.superscript(node, mock_recur_render))
    end)

    it("should render x^mock_rendered(complex_exponent)", function()
      local node = {
        type = "superscript",
        base = { type = "variable", name = "x" },
        exponent = { type = "sqrt", radicand = {type="number", value=2} }
      }
      assert.are.equal("x^mock_rendered(sqrt)", handlers.superscript(node, mock_recur_render))
    end)
  end)

  describe("subscript handler", function()
    it("should render Subscript[base,subscript]", function()
      local node = {
        type = "subscript",
        base = { type = "variable", name = "y" },
        subscript = { type = "number", value = 1 }
      }
      assert.are.equal("Subscript[y,1]", handlers.subscript(node, mock_recur_render))
      assert.spy(mock_recur_render).was.called_with(node.base)
      assert.spy(mock_recur_render).was.called_with(node.subscript)
    end)

    it("should render Subscript for complex base and subscript", function()
      local node = {
        type = "subscript",
        base = { type = "greek", name = "Omega" },
        subscript = { type = "binary", operator = "+", left={type="variable", name="i"}, right={type="number", value=1}}
      }
      assert.are.equal("Subscript[Omega,i+1]", handlers.subscript(node, mock_recur_render))
    end)
  end)

  describe("unary handler", function()
    it("should render -value for negative unary operator", function()
      local node = { type = "unary", operator = "-", value = { type = "number", value = 5 } }
      assert.are.equal("-5", handlers.unary(node, mock_recur_render))
      assert.spy(mock_recur_render).was.called_with(node.value)
    end)

    it("should render +value for positive unary operator", function()
      local node = { type = "unary", operator = "+", value = { type = "variable", name = "z" } }
      assert.are.equal("+z", handlers.unary(node, mock_recur_render))
    end)

    it("should render operator with complex value", function()
      local node = { type = "unary", operator = "-", value = { type = "fraction", numerator={type="number", value=1}, denominator={type="number", value=2}} }
      assert.are.equal("-mock_rendered(fraction)", handlers.unary(node, mock_recur_render))
    end)
  end)

  describe("function_call handler", function()
    it("should correctly render sin(x)", function()
      local var_node_sin_name = ast.create_symbol_node("sin")
      local var_node_x_arg = ast.create_symbol_node("x")
      local node = ast.create_function_call_node(
        var_node_sin_name,
        { var_node_x_arg }
      )
      assert.are.same("Sin[x]", render_node_for_function_call(node))
    end)

    it("should correctly render cos(theta)", function()
      local node = ast.create_function_call_node(
        ast.create_symbol_node("cos"),
        { ast.create_symbol_node("theta") }
      )
      assert.are.same("Cos[theta]", render_node_for_function_call(node))
    end)

    it("should correctly render log(x)", function()
      local node = ast.create_function_call_node(
        ast.create_symbol_node("log"),
        { ast.create_symbol_node("x") }
      )
      assert.are.same("Log[x]", render_node_for_function_call(node))
    end)

    it("should correctly render ln(y)", function()
      local node = ast.create_function_call_node(
        ast.create_symbol_node("ln"),
        { ast.create_symbol_node("y") }
      )
      assert.are.same("Log[y]", render_node_for_function_call(node))
    end)

    it("should correctly render log10(z)", function()
      local node = ast.create_function_call_node(
        ast.create_symbol_node("log10"),
        { ast.create_symbol_node("z") }
      )
      assert.are.same("Log10[z]", render_node_for_function_call(node))
    end)

    it("should correctly render exp(x+1)", function()
      local arg_node = ast.create_binary_operation_node(
          "+",
          ast.create_symbol_node("x"),
          { type = "number", value = 1 }
      )
      local node = ast.create_function_call_node(
        ast.create_symbol_node("exp"),
        { arg_node }
      )
      assert.are.same("Exp[x+1]", render_node_for_function_call(node))
    end)

    it("should use capitalized name for unknown function and log a warning", function()
      local logger = require("tungsten.util.logger")
      stub(logger, "notify")

      local node = ast.create_function_call_node(
        ast.create_symbol_node("myCustomFunc"),
        { ast.create_symbol_node("a") }
      )
      assert.are.same("MyCustomFunc[a]", render_node_for_function_call(node))
      assert.spy(logger.notify).was.called()

      logger.notify:revert()
    end)
  end)
end)

