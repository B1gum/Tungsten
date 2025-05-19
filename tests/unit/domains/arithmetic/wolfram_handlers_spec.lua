-- tests/unit/domains/arithmetic/wolfram_handlers_spec.lua

package.path = './lua/?.lua;./lua/?/init.lua;' .. package.path

local spy = require('luassert.spy')
local wolfram_handlers = require("tungsten.domains.arithmetic.wolfram_handlers")

describe("Tungsten Arithmetic Wolfram Handlers", function()
  local handlers = wolfram_handlers.handlers
  local mock_recur_render

  before_each(function()
    mock_recur_render = spy.new(function(child_node)
      if child_node.type == "number" then return tostring(child_node.value) end
      if child_node.type == "variable" then return child_node.name end
      if child_node.type == "greek" then return child_node.name end
      if child_node.type == "binary" then
        -- Simplified mock for binary children within other handlers,
        -- assumes no complex precedence needed for children *of* fraction, sqrt etc.
        return mock_recur_render(child_node.left) .. child_node.operator .. mock_recur_render(child_node.right)
      end
      return "mock_rendered(" .. child_node.type .. ")"
    end)
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
      local node = { type = "greek", name = "Omega" } -- Assuming input is already Omega
      assert.are.equal("Omega", handlers.greek(node, mock_recur_render))
    end)
  end)

  describe("binary handler (bin_with_parens)", function()
    local prec = wolfram_handlers.precedence -- Access precedence from the module
    local function recur_render_for_binary(node)
      if node.type == "number" then return tostring(node.value) end
      if node.type == "variable" then return node.name end
      if node.type == "binary" then
        -- For testing binary handler, this recur_render needs to call the binary handler itself
        -- to correctly test parenthesization based on child operator precedence.
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

    -- Parenthesization tests
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
      -- The current bin_with_parens logic (child_prec < parent_prec) would produce 'a-b+c'.
      -- This test asserts the mathematically correct 'a-(b+c)' for Wolfram Language.
      -- This test will likely fail with the current implementation and highlights a need for more nuanced parenthesization.
      assert.are.equal("a-(b+c)", handlers.binary(node, recur_render_for_binary))
    end)

    it("a - (b - c) should be rendered as a-(b-c) for correctness", function()
      local node = {
        type = "binary", operator = "-",
        left = { type = "variable", name = "a" },
        right = { type = "binary", operator = "-", left = { type = "variable", name = "b" }, right = { type = "variable", name = "c" } }
      }
      -- The current bin_with_parens logic (child_prec < parent_prec) would produce 'a-b-c'.
      -- This test asserts the mathematically correct 'a-(b-c)' for Wolfram Language.
      -- This test is expected to fail with the current implementation and correctly identifies this behavior.
      assert.are.equal("a-(b-c)", handlers.binary(node, recur_render_for_binary))
    end)

    it("a / (b * c) should be rendered as a/(b*c) (no parens for higher precedence child on right)", function()
      local node = {
        type = "binary", operator = "/",
        left = { type = "variable", name = "a" },
        right = { type = "binary", operator = "*", left = { type = "variable", name = "b" }, right = { type = "variable", name = "c" } }
      }
      -- Current logic: child_prec (2) is not less than parent_prec (2), so no parens. Produces 'a/b*c'.
      -- This is ' (a/b) * c '.
      -- For 'a/(b*c)', Wolfram would need 'a/(b*c)'.
      -- This test asserts the desired behavior.
      assert.are.equal("a/(b*c)", handlers.binary(node, recur_render_for_binary))
    end)

    it("(a * b) / c should be rendered as (a*b)/c (no parens for higher precedence on left)", function()
      local node = {
        type = "binary", operator = "/",
        left = { type = "binary", operator = "*", left = { type = "variable", name = "a" }, right = { type = "variable", name = "b" } },
        right = { type = "variable", name = "c" }
      }
      -- Current logic: child_prec (2) is not less than parent_prec (2), so no parens. Produces 'a*b/c'. This is correct.
      assert.are.equal("a*b/c", handlers.binary(node, recur_render_for_binary))
    end)


    it("a ^ (b + c) should be rendered as a^(b+c)", function()
      local node = {
        type = "binary", operator = "^",
        left = { type = "variable", name = "a" },
        right = { type = "binary", operator = "+", left = { type = "variable", name = "b" }, right = { type = "variable", name = "c" } }
      }
      -- Child '+' (prec 1) < parent '^' (prec 3) is true. Parens added. Correct.
      assert.are.equal("a^(b+c)", handlers.binary(node, recur_render_for_binary))
    end)

    it("(a + b) ^ c should be rendered as (a+b)^c", function()
      local node = {
        type = "binary", operator = "^",
        left = { type = "binary", operator = "+", left = { type = "variable", name = "a" }, right = { type = "variable", name = "b" } },
        right = { type = "variable", name = "c" }
      }
      -- Child '+' (prec 1) < parent '^' (prec 3) is true. Parens added. Correct.
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
      -- Mock recur_render for binary will produce "a+b"
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
end)
