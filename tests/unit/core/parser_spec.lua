-- tests/unit/core/parser_spec.lua
-- Unit tests for the LPeg parser functionality in core/parser.lua
---------------------------------------------------------------------

package.path = './lua/?.lua;./lua/?/init.lua;' .. package.path

local parser = require("tungsten.core.parser")
require("tungsten.core")
local ast_utils = require("tungsten.core.ast")

describe("tungsten.core.parser.parse with combined grammar", function()
  local function parse_input(input_str)
    return parser.parse(input_str)
  end

  describe("basic arithmetic operations", function()
    it("should parse addition: 1 + 2", function()
      local input = "1 + 2"
      local expected_ast = ast_utils.create_binary_operation_node("+",
        { type = "number", value = 1 },
        { type = "number", value = 2 }
      )
      assert.are.same(expected_ast, parse_input(input))
    end)

    it("should parse subtraction: 2 - 1", function()
      local input = "2 - 1"
      local expected_ast = ast_utils.create_binary_operation_node("-",
        { type = "number", value = 2 },
        { type = "number", value = 1 }
      )
      assert.are.same(expected_ast, parse_input(input))
    end)

    it("should parse multiplication with *: 3 * 4 (verifying * operator)", function()
      local input = "3 * 4"
      local expected_ast = ast_utils.create_binary_operation_node("*",
        { type = "number", value = 3 },
        { type = "number", value = 4 }
      )
      assert.are.same(expected_ast, parse_input(input))
    end)

    it("should parse multiplication with \\cdot: 3 \\cdot 4", function()
      local input = "3 \\cdot 4"
      local expected_ast = ast_utils.create_binary_operation_node("*",
        { type = "number", value = 3 },
        { type = "number", value = 4 }
      )
      assert.are.same(expected_ast, parse_input(input))
    end)

    it("should parse division: 5 / 6", function()
      local input = "5 / 6"
      local expected_ast = ast_utils.create_binary_operation_node("/",
        { type = "number", value = 5 },
        { type = "number", value = 6 }
      )
      assert.are.same(expected_ast, parse_input(input))
    end)
  end)

  describe("order of operations", function()
    it("should parse 1 + 2 \\cdot 3 correctly (multiplication before addition)", function()
      local input = "1 + 2 \\cdot 3"
      local expected_ast = ast_utils.create_binary_operation_node("+",
        { type = "number", value = 1 },
        ast_utils.create_binary_operation_node("*",
          { type = "number", value = 2 },
          { type = "number", value = 3 }
        )
      )
      assert.are.same(expected_ast, parse_input(input))
    end)

    it("should parse 1 \\cdot 2 + 3 correctly (multiplication before addition)", function()
      local input = "1 \\cdot 2 + 3"
      local expected_ast = ast_utils.create_binary_operation_node("+",
        ast_utils.create_binary_operation_node("*",
          { type = "number", value = 1 },
          { type = "number", value = 2 }
        ),
        { type = "number", value = 3 }
      )
      assert.are.same(expected_ast, parse_input(input))
    end)
  end)

  describe("parenthesized expressions", function()
    it("should parse (1 + 2) \\cdot 3 correctly", function()
      local input = "(1 + 2) \\cdot 3"
      local expected_ast = ast_utils.create_binary_operation_node("*",
        ast_utils.create_binary_operation_node("+",
          { type = "number", value = 1 },
          { type = "number", value = 2 }
        ),
        { type = "number", value = 3 }
      )
      assert.are.same(expected_ast, parse_input(input))
    end)

    it("should parse 1 \\cdot (2 + 3) correctly", function()
        local input = "1 \\cdot (2 + 3)"
        local expected_ast = ast_utils.create_binary_operation_node("*",
            { type = "number", value = 1 },
            ast_utils.create_binary_operation_node("+",
                { type = "number", value = 2 },
                { type = "number", value = 3 }
            )
        )
        assert.are.same(expected_ast, parse_input(input))
    end)
  end)

  describe("fractions", function()
    it("should parse \\frac{a}{b}", function()
      local input = "\\frac{a}{b}"
      local expected_ast = ast_utils.create_fraction_node(
        { type = "variable", name = "a" },
        { type = "variable", name = "b" }
      )
      assert.are.same(expected_ast, parse_input(input))
    end)

    it("should parse \\frac{1+x}{y-2}", function()
      local input = "\\frac{1+x}{y-2}"
      local expected_ast = ast_utils.create_fraction_node(
        ast_utils.create_binary_operation_node("+",
          { type = "number", value = 1 },
          { type = "variable", name = "x" }
        ),
        ast_utils.create_binary_operation_node("-",
          { type = "variable", name = "y" },
          { type = "number", value = 2 }
        )
      )
      assert.are.same(expected_ast, parse_input(input))
    end)
  end)

  describe("square roots", function()
    it("should parse \\sqrt{x}", function()
      local input = "\\sqrt{x}"
      local expected_ast = ast_utils.create_sqrt_node(
        { type = "variable", name = "x" },
        nil
      )
      assert.are.same(expected_ast, parse_input(input))
    end)

    it("should parse \\sqrt[3]{y}", function()
      local input = "\\sqrt[3]{y}"
      local expected_ast = ast_utils.create_sqrt_node(
        { type = "variable", name = "y" },
        { type = "number", value = 3 }
      )
      assert.are.same(expected_ast, parse_input(input))
    end)

    it("should parse \\sqrt{x^2+y^2}", function()
        local input = "\\sqrt{x^2+y^2}"
        local expected_ast = ast_utils.create_sqrt_node(
            ast_utils.create_binary_operation_node("+",
                ast_utils.create_superscript_node(
                    { type = "variable", name = "x"},
                    { type = "number", value = 2}
                ),
                ast_utils.create_superscript_node(
                    { type = "variable", name = "y"},
                    { type = "number", value = 2}
                )
            ),
            nil
        )
        assert.are.same(expected_ast, parse_input(input))
    end)
  end)

  describe("superscripts and subscripts", function()
    it("should parse x^2", function()
      local input = "x^2"
      local expected_ast = ast_utils.create_superscript_node(
        { type = "variable", name = "x" },
        { type = "number", value = 2 }
      )
      assert.are.same(expected_ast, parse_input(input))
    end)

    it("should parse y_i", function()
      local input = "y_i"
      local expected_ast = ast_utils.create_subscript_node(
        { type = "variable", name = "y" },
        { type = "variable", name = "i" }
      )
      assert.are.same(expected_ast, parse_input(input))
    end)

    it("should parse z_i^2 (subscript then superscript)", function()
      local input = "z_i^2"
      local expected_ast = ast_utils.create_superscript_node(
        ast_utils.create_subscript_node(
          { type = "variable", name = "z" },
          { type = "variable", name = "i" }
        ),
        { type = "number", value = 2 }
      )
      assert.are.same(expected_ast, parse_input(input))
    end)

    it("should parse x^{a+b}", function()
        local input = "x^{a+b}"
        local expected_ast = ast_utils.create_superscript_node(
            { type = "variable", name = "x" },
            ast_utils.create_binary_operation_node("+",
                {type = "variable", name = "a"},
                {type = "variable", name = "b"}
            )
        )
        assert.are.same(expected_ast, parse_input(input))
    end)
  end)

  describe("unary operators", function()
    it("should parse -5", function()
      local input = "-5"
      local expected_ast = ast_utils.create_unary_operation_node(
        "-",
        { type = "number", value = 5 }
      )
      assert.are.same(expected_ast, parse_input(input))
    end)

    it("should parse +x", function()
      local input = "+x"
      local expected_ast = ast_utils.create_unary_operation_node(
        "+",
        { type = "variable", name = "x" }
      )
      assert.are.same(expected_ast, parse_input(input))
    end)

    it("should parse -(1+2)", function()
        local input = "-(1+2)"
        local expected_ast = ast_utils.create_unary_operation_node(
            "-",
            ast_utils.create_binary_operation_node("+",
                {type = "number", value = 1},
                {type = "number", value = 2}
            )
        )
        assert.are.same(expected_ast, parse_input(input))
    end)
  end)

  describe("variables and Greek letters", function()
    it("should parse a single variable x", function()
      local input = "x"
      local expected_ast = { type = "variable", name = "x" }
      assert.are.same(expected_ast, parse_input(input))
    end)

    it("should parse a multi-character variable 'alphaPrime'", function()
      local input = "alphaPrime"
      local expected_ast = { type = "variable", name = "alphaPrime" }
      assert.are.same(expected_ast, parse_input(input))
    end)

    it("should parse \\alpha", function()
      local input = "\\alpha"
      local expected_ast = { type = "greek", name = "alpha" }
      assert.are.same(expected_ast, parse_input(input))
    end)

    it("should parse \\beta + \\gamma", function()
        local input = "\\beta + \\gamma"
        local expected_ast = ast_utils.create_binary_operation_node("+",
            {type="greek", name="beta"},
            {type="greek", name="gamma"}
        )
        assert.are.same(expected_ast, parse_input(input))
    end)
  end)

  describe("implicit multiplication", function()
    it("should parse 2x as 2 \\cdot x (implicitly)", function()
      local input = "2x"
      local expected_ast = ast_utils.create_binary_operation_node("*",
        { type = "number", value = 2 },
        { type = "variable", name = "x" }
      )
      assert.are.same(expected_ast, parse_input(input))
    end)
    it("should parse x y as x \\cdot y (implicitly)", function()
      local input = "x y"
      local expected_ast = ast_utils.create_binary_operation_node("*",
        { type = "variable", name = "x" },
        { type = "variable", name = "y" }
      )
      assert.are.same(expected_ast, parse_input(input))
    end)
    it("should parse (1+2)x as (1+2) \\cdot x (implicitly)", function()
        local input = "(1+2)x"
        local expected_ast = ast_utils.create_binary_operation_node("*",
            ast_utils.create_binary_operation_node("+",
                { type = "number", value = 1 },
                { type = "number", value = 2 }
            ),
            { type = "variable", name = "x" }
        )
        assert.are.same(expected_ast, parse_input(input))
    end)
    it("should parse 2\\alpha as 2 \\cdot \\alpha (implicitly)", function()
        local input = "2\\alpha"
        local expected_ast = ast_utils.create_binary_operation_node("*",
            { type = "number", value = 2 },
            { type = "greek", name = "alpha" }
        )
        assert.are.same(expected_ast, parse_input(input))
    end)
  end)

  describe("invalid syntax", function()
    it("should return nil for unmatched parenthesis: (1 + 2", function()
      local input = "(1 + 2"
      assert.is_nil(parse_input(input))
    end)

    it("should return nil for misplaced operator: 1 + \\cdot 2", function()
      local input = "1 + \\cdot 2"
      assert.is_nil(parse_input(input))
    end)

    it("should return nil for incomplete fraction: \\frac{1}", function()
      local input = "\\frac{1}"
      assert.is_nil(parse_input(input))
    end)

    it("should return nil for incomplete sqrt: \\sqrt[3]", function()
      local input = "\\sqrt[3]"
      assert.is_nil(parse_input(input))
    end)

    it("should return nil for bad superscript: x^", function()
        local input = "x^"
        assert.is_nil(parse_input(input))
    end)

    it("should return nil for just an operator: +", function()
        local input = "+"
        assert.is_nil(parse_input(input))
    end)
  end)

  describe("edge cases and complex structures", function()
    it("should parse nested fractions: \\frac{\\frac{a}{b}}{\\frac{c}{d}}", function()
        local input = "\\frac{\\frac{a}{b}}{\\frac{c}{d}}"
        local expected_ast = ast_utils.create_fraction_node(
            ast_utils.create_fraction_node(
                {type="variable", name="a"},
                {type="variable", name="b"}
            ),
            ast_utils.create_fraction_node(
                {type="variable", name="c"},
                {type="variable", name="d"}
            )
        )
        assert.are.same(expected_ast, parse_input(input))
    end)

    it("should parse expression with mixed brackets: [(1+2)\\cdot{3-4}]/5", function()
        local input = "[(1+2)\\cdot{3-4}]/5"
        local expected_ast = ast_utils.create_binary_operation_node("/",
            ast_utils.create_binary_operation_node("*",
                ast_utils.create_binary_operation_node("+",
                    { type = "number", value = 1 },
                    { type = "number", value = 2 }
                ),
                ast_utils.create_binary_operation_node("-",
                    { type = "number", value = 3 },
                    { type = "number", value = 4 }
                )
            ),
            { type = "number", value = 5 }
        )
        assert.are.same(expected_ast, parse_input(input))
    end)
  end)

  describe("calculus and arithmetic integration", function()
    it("should parse derivative of a fraction: \\frac{d}{dx} \\frac{x^2}{x+1}", function()
      local input = "\\frac{d}{dx} \\frac{x^2}{x+1}"
      local expected_ast = ast_utils.create_ordinary_derivative_node(
        ast_utils.create_fraction_node(
          ast_utils.create_superscript_node(
            { type = "variable", name = "x" },
            { type = "number", value = 2 }
          ),
          ast_utils.create_binary_operation_node("+",
            { type = "variable", name = "x" },
            { type = "number", value = 1 }
          )
        ),
        { type = "variable", name = "x" },
        { type = "number", value = 1 }
      )
      assert.are.same(expected_ast, parse_input(input))
    end)

    it("should parse integral of an expression with variables and numbers: \\int x^2 + 2x dx", function()
      local input = "\\int x^2 + 2x dx"
      local expected_ast = ast_utils.create_indefinite_integral_node(
        ast_utils.create_binary_operation_node("+",
          ast_utils.create_superscript_node(
            { type = "variable", name = "x" },
            { type = "number", value = 2 }
          ),
          ast_utils.create_binary_operation_node("*",
            { type = "number", value = 2 },
            { type = "variable", name = "x" }
          )
        ),
        { type = "variable", name = "x" }
      )
      assert.are.same(expected_ast, parse_input(input))
    end)

    it("should parse limit of a fraction: \\lim_{x \\to 0} \\frac{\\sin x}{x}", function()
      local input = "\\lim_{x \\to 0} \\frac{\\sin x}{x}"
      local expected_ast = ast_utils.create_limit_node(
        { type = "variable", name = "x" },
        { type = "number", value = 0 },
        ast_utils.create_fraction_node(
          ast_utils.create_function_call_node(
            { type = "variable", name = "sin" },
            { { type = "variable", name = "x" } }
          ),
          { type = "variable", name = "x" }
        )
      )
      local parsed_ast = parse_input(input)
      assert.are.equal("limit", parsed_ast.type)
      assert.are.same({ type = "variable", name = "x" }, parsed_ast.variable)
      assert.are.same({ type = "number", value = 0 }, parsed_ast.point)
      assert.are.equal("fraction", parsed_ast.expression.type)
      if parsed_ast.expression.numerator.type == "function_call" then
         assert.are.same({ type = "variable", name = "sin" }, parsed_ast.expression.numerator.name_node)
         assert.are.same({{ type = "variable", name = "x" }}, parsed_ast.expression.numerator.args)
      else
        assert.fail("Numerator for \\sin x did not parse as function_call or implicit multiplication.")
      end
      assert.are.same({ type = "variable", name = "x" }, parsed_ast.expression.denominator)
    end)

    it("should parse sum with arithmetic in body: \\sum_{i=0}^{N} (i^2 + \\frac{1}{i})", function()
      local input = "\\sum_{i=0}^{N} (i^2 + \\frac{1}{i})"
      local expected_ast = ast_utils.create_summation_node(
        { type = "variable", name = "i" },
        { type = "number", value = 0 },
        { type = "variable", name = "N" },
        ast_utils.create_binary_operation_node("+",
          ast_utils.create_superscript_node(
            { type = "variable", name = "i" },
            { type = "number", value = 2 }
          ),
          ast_utils.create_fraction_node(
            { type = "number", value = 1 },
            { type = "variable", name = "i" }
          )
        )
      )
      assert.are.same(expected_ast, parse_input(input))
    end)

    it("should parse partial derivative of a product: \\frac{\\partial}{\\partial x} (x^2 y)", function()
      local input = "\\frac{\\partial}{\\partial x} (x^2 y)"
      local expected_ast = ast_utils.create_partial_derivative_node(
        ast_utils.create_binary_operation_node("*",
          ast_utils.create_superscript_node(
            { type = "variable", name = "x" },
            { type = "number", value = 2 }
          ),
          { type = "variable", name = "y" }
        ),
        { type = "number", value = 1 },
        {
          ast_utils.create_differentiation_term_node(
            { type = "variable", name = "x" },
            { type = "number", value = 1 }
          )
        }
      )
      assert.are.same(expected_ast, parse_input(input))
    end)

    it("should parse arithmetic operation on two calculus terms: \\int x dx + \\lim_{x \\to 0} x^2", function()
        local input = "\\int x dx + \\lim_{x \\to 0} x^2"
        local expected_ast = ast_utils.create_binary_operation_node("+",
            ast_utils.create_indefinite_integral_node(
                { type = "variable", name = "x" },
                { type = "variable", name = "x" }
            ),
            ast_utils.create_limit_node(
                { type = "variable", name = "x" },
                { type = "number", value = 0 },
                ast_utils.create_superscript_node(
                    { type = "variable", name = "x" },
                    { type = "number", value = 2 }
                )
            )
        )
        assert.are.same(expected_ast, parse_input(input))
    end)
  end)
end)
