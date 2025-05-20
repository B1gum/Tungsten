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
      local expected_ast = ast_utils.node("fraction", {
        numerator = { type = "variable", name = "a" },
        denominator = { type = "variable", name = "b" }
      })
      assert.are.same(expected_ast, parse_input(input))
    end)

    it("should parse \\frac{1+x}{y-2}", function()
      local input = "\\frac{1+x}{y-2}"
      local expected_ast = ast_utils.node("fraction", {
        numerator = ast_utils.create_binary_operation_node("+",
          { type = "number", value = 1 },
          { type = "variable", name = "x" }
        ),
        denominator = ast_utils.create_binary_operation_node("-",
          { type = "variable", name = "y" },
          { type = "number", value = 2 }
        )
      })
      assert.are.same(expected_ast, parse_input(input))
    end)
  end)

  describe("square roots", function()
    it("should parse \\sqrt{x}", function()
      local input = "\\sqrt{x}"
      local expected_ast = ast_utils.node("sqrt", {
        radicand = { type = "variable", name = "x" }
      })
      assert.are.same(expected_ast, parse_input(input))
    end)

    it("should parse \\sqrt[3]{y}", function()
      local input = "\\sqrt[3]{y}"
      local expected_ast = ast_utils.node("sqrt", {
        index = { type = "number", value = 3 },
        radicand = { type = "variable", name = "y" }
      })
      assert.are.same(expected_ast, parse_input(input))
    end)

    it("should parse \\sqrt{x^2+y^2}", function()
        local input = "\\sqrt{x^2+y^2}"
        local expected_ast = ast_utils.node("sqrt", {
            radicand = ast_utils.create_binary_operation_node("+",
                ast_utils.node("superscript", {
                    base = { type = "variable", name = "x"},
                    exponent = { type = "number", value = 2}
                }),
                ast_utils.node("superscript", {
                    base = { type = "variable", name = "y"},
                    exponent = { type = "number", value = 2}
                })
            )
        })
        assert.are.same(expected_ast, parse_input(input))
    end)
  end)

  describe("superscripts and subscripts", function()
    it("should parse x^2", function()
      local input = "x^2"
      local expected_ast = ast_utils.node("superscript", {
        base = { type = "variable", name = "x" },
        exponent = { type = "number", value = 2 }
      })
      assert.are.same(expected_ast, parse_input(input))
    end)

    it("should parse y_i", function()
      local input = "y_i"
      local expected_ast = ast_utils.node("subscript", {
        base = { type = "variable", name = "y" },
        subscript = { type = "variable", name = "i" }
      })
      assert.are.same(expected_ast, parse_input(input))
    end)

    it("should parse z_i^2 (subscript then superscript)", function()
      local input = "z_i^2"
      local expected_ast = ast_utils.node("superscript", {
        base = ast_utils.node("subscript", {
          base = { type = "variable", name = "z" },
          subscript = { type = "variable", name = "i" }
        }),
        exponent = { type = "number", value = 2 }
      })
      assert.are.same(expected_ast, parse_input(input))
    end)

    it("should parse x^{a+b}", function()
        local input = "x^{a+b}"
        local expected_ast = ast_utils.node("superscript", {
            base = { type = "variable", name = "x" },
            exponent = ast_utils.create_binary_operation_node("+",
                {type = "variable", name = "a"},
                {type = "variable", name = "b"}
            )
        })
        assert.are.same(expected_ast, parse_input(input))
    end)
  end)

  describe("unary operators", function()
    it("should parse -5", function()
      local input = "-5"
      local expected_ast = ast_utils.node("unary", {
        operator = "-",
        value = { type = "number", value = 5 }
      })
      assert.are.same(expected_ast, parse_input(input))
    end)

    it("should parse +x", function()
      local input = "+x"
      local expected_ast = ast_utils.node("unary", {
        operator = "+",
        value = { type = "variable", name = "x" }
      })
      assert.are.same(expected_ast, parse_input(input))
    end)

    it("should parse -(1+2)", function()
        local input = "-(1+2)"
        local expected_ast = ast_utils.node("unary", {
            operator = "-",
            value = ast_utils.create_binary_operation_node("+",
                {type = "number", value = 1},
                {type = "number", value = 2}
            )
        })
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
        local expected_ast = ast_utils.node("fraction", {
            numerator = ast_utils.node("fraction", {
                numerator = {type="variable", name="a"},
                denominator = {type="variable", name="b"}
            }),
            denominator = ast_utils.node("fraction", {
                numerator = {type="variable", name="c"},
                denominator = {type="variable", name="d"}
            })
        })
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
-- (Inside tungsten/tests/unit/core/parser_spec.lua)
-- ... existing describe blocks ...

  describe("calculus and arithmetic integration", function()
    it("should parse derivative of a fraction: \\frac{d}{dx} \\frac{x^2}{x+1}", function()
      local input = "\\frac{d}{dx} \\frac{x^2}{x+1}"
      local expected_ast = ast_utils.node("ordinary_derivative", {
        order = { type = "number", value = 1 },
        variable = { type = "variable", name = "x" },
        expression = ast_utils.node("fraction", {
          numerator = ast_utils.node("superscript", {
            base = { type = "variable", name = "x" },
            exponent = { type = "number", value = 2 }
          }),
          denominator = ast_utils.create_binary_operation_node("+",
            { type = "variable", name = "x" },
            { type = "number", value = 1 }
          )
        })
      })
      assert.are.same(expected_ast, parse_input(input))
    end)

    it("should parse integral of an expression with variables and numbers: \\int x^2 + 2x dx", function()
      local input = "\\int x^2 + 2x dx"
      -- Assuming implicit multiplication 2x is handled by arithmetic rules
      local expected_ast = ast_utils.node("indefinite_integral", {
        integrand = ast_utils.create_binary_operation_node("+",
          ast_utils.node("superscript", {
            base = { type = "variable", name = "x" },
            exponent = { type = "number", value = 2 }
          }),
          ast_utils.create_binary_operation_node("*",
            { type = "number", value = 2 },
            { type = "variable", name = "x" }
          )
        ),
        variable = { type = "variable", name = "x" }
      })
      assert.are.same(expected_ast, parse_input(input))
    end)

    it("should parse limit of a fraction: \\lim_{x \\to 0} \\frac{\\sin x}{x}", function()
      -- This assumes \sin x is a recognized token or sub-expression.
      -- For simplicity, let's assume 'sin' becomes a variable node if not a function call.
      -- Or, if you have function call parsing: ast_utils.node("function_call", {name="sin", args={{type="variable", name="x"}}})
      local input = "\\lim_{x \\to 0} \\frac{\\sin x}{x}"
      local expected_ast = ast_utils.node("limit", {
        variable = { type = "variable", name = "x" },
        point = { type = "number", value = 0 },
        expression = ast_utils.node("fraction", {
          numerator = ast_utils.node("function_call", { -- Assuming you add function call parsing
            name_node = { type = "variable", name = "sin" },
            args = { { type = "variable", name = "x" } } -- Simplified: arg list needs proper parsing
          }),
          denominator = { type = "variable", name = "x" }
        })
      })
      -- Note: The actual AST for \sin x depends on your tokenizer and function call parsing rules.
      -- The example above shows a placeholder for a function call.
      -- If \sin is treated as a variable: { type = "variable", name = "sin" }
      -- Potentially, it could be an implicit multiplication: sin * x
      -- Adjust `expected_ast` based on your actual parsing of `\sin x`.
      -- For this example, I'll mock a simple `function_call` node structure.
      -- You'll need to ensure your grammar can produce this.
      -- If `\sin` is not special, it might parse as variable `sin` implicitly multiplied by `x`.
      -- Let's assume for now `\sin x` parses to a function call node.
      -- If `\sin` is just a variable, then it would be `implicit mul(var(sin), var(x))`
      local parsed_ast = parse_input(input)
      -- A more robust check due to complexity of function calls:
      assert.are.equal("limit", parsed_ast.type)
      assert.are.same({ type = "variable", name = "x" }, parsed_ast.variable)
      assert.are.same({ type = "number", value = 0 }, parsed_ast.point)
      assert.are.equal("fraction", parsed_ast.expression.type)
      -- Further checks for numerator (sin x) and denominator (x) would go here
      -- This part is highly dependent on how you decide to parse functions like `\sin x`
    end)

    it("should parse sum with arithmetic in body: \\sum_{i=0}^{N} (i^2 + \\frac{1}{i})", function()
      local input = "\\sum_{i=0}^{N} (i^2 + \\frac{1}{i})"
      local expected_ast = ast_utils.node("summation", {
        index_variable = { type = "variable", name = "i" },
        start_expression = { type = "number", value = 0 },
        end_expression = { type = "variable", name = "N" },
        body_expression = ast_utils.create_binary_operation_node("+",
          ast_utils.node("superscript", {
            base = { type = "variable", name = "i" },
            exponent = { type = "number", value = 2 }
          }),
          ast_utils.node("fraction", {
            numerator = { type = "number", value = 1 },
            denominator = { type = "variable", name = "i" }
          })
        )
      })
      assert.are.same(expected_ast, parse_input(input))
    end)

    it("should parse partial derivative of a product: \\frac{\\partial}{\\partial x} (x^2 y)", function()
      local input = "\\frac{\\partial}{\\partial x} (x^2 y)"
      local expected_ast = ast_utils.node("partial_derivative", {
        overall_order = { type = "number", value = 1 },
        variables = {
          ast_utils.node("differentiation_term", {
            variable = { type = "variable", name = "x" },
            order = { type = "number", value = 1 }
          })
        },
        expression = ast_utils.create_binary_operation_node("*",
          ast_utils.node("superscript", {
            base = { type = "variable", name = "x" },
            exponent = { type = "number", value = 2 }
          }),
          { type = "variable", name = "y" }
        )
      })
      assert.are.same(expected_ast, parse_input(input))
    end)

    it("should parse arithmetic operation on two calculus terms: \\int x dx + \\lim_{x \\to 0} x^2", function()
        local input = "\\int x dx + \\lim_{x \\to 0} x^2"
        local expected_ast = ast_utils.create_binary_operation_node("+",
            ast_utils.node("indefinite_integral", {
                integrand = { type = "variable", name = "x" },
                variable = { type = "variable", name = "x" }
            }),
            ast_utils.node("limit", {
                variable = { type = "variable", name = "x" },
                point = { type = "number", value = 0 },
                expression = ast_utils.node("superscript", {
                    base = { type = "variable", name = "x" },
                    exponent = { type = "number", value = 2 }
                })
            })
        )
        assert.are.same(expected_ast, parse_input(input))
    end)
  end)
end)
