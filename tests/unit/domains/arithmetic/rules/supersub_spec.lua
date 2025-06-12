-- tungsten/tests/unit/domains/arithmetic/rules/supersub_spec.lua
package.path = './lua/?.lua;./lua/?/init.lua;' .. package.path

local lpeg = require "lpeg"
local P, V, C, R, S, Cg, Ct, Cf = lpeg.P, lpeg.V, lpeg.C, lpeg.R, lpeg.S, lpeg.Cg, lpeg.Ct, lpeg.Cf

local SupSubRule
local UnaryRule

local mock_tokenizer_module
local mock_ast_module
local modules_to_reset = {
  "tungsten.domains.arithmetic.rules.supersub",
  "tungsten.core.tokenizer",
  "tungsten.core.ast",
}

local test_grammar_table_definition
local compiled_test_grammar

local function base_node(name_or_val, type, sub_props)
  local node = { type = type }
  if type == "number" then
    node.value = name_or_val
  elseif type == "variable" then
    node.name = name_or_val
  elseif type == "matrix" then
    node.id = name_or_val
  elseif type == "symbolic_vector" then
    node.name_expr = { type = "variable", name = name_or_val }
  elseif type == "group_placeholder" then
    node.content = name_or_val
  elseif type == "intercal_command" then
  else
    node.value = name_or_val
  end
  if sub_props then
    for k, v in pairs(sub_props) do
      node[k] = v
    end
  end
  return node
end

describe("Arithmetic SupSub Rule: tungsten.domains.arithmetic.rules.supersub", function()

  before_each(function()
    for _, name in ipairs(modules_to_reset) do
      package.loaded[name] = nil
    end

    mock_tokenizer_module = {
      space = S(" \t\n\r")^0,
      lbrace = P("{"),
      rbrace = P("}"),
      lparen = P("("),
      rparen = P(")"),
      variable = C(R("AZ","az") * (R("AZ","az","09")^0)) / function(s)
        if s == "T" then return {type="variable", name="T"} end
        if s == "intercal" then return {type="intercal_command"} end
        return base_node(s, "variable")
      end,
      number = C( (P("-")^-1 * R("09")^1 * (P(".")*R("09")^1)^-1) ) / function(s) return base_node(tonumber(s), "number") end,
      matrix_placeholder = P"Matrix" * C(R("AZ")) / function(id) return base_node(id, "matrix") end,
      vector_placeholder = P"\\vec{" * C(R("az")) * P"}" / function(name) return base_node(name, "symbolic_vector") end,
    }
    package.loaded["tungsten.core.tokenizer"] = mock_tokenizer_module

    mock_ast_module = {
      create_transpose_node = function(expression_ast)
        return { type = "transpose", expression = expression_ast }
      end,
      create_inverse_node = function(expression_ast)
        return { type = "inverse", expression = expression_ast }
      end,
      create_superscript_node = function(b, e) return {type="superscript", base=b, exponent=e} end,
      create_subscript_node = function(b, s) return {type="subscript", base=b, subscript=s} end,
      create_unary_operation_node = function(op, val) return { type = "unary", operator = op, value = val} end,
      create_binary_operation_node = function(op, l, r) return { type="binary", operator=op, left=l, right=r} end,
    }
    package.loaded["tungsten.core.ast"] = mock_ast_module

    local Rules = require("tungsten.domains.arithmetic.rules.supersub")
    SupSubRule = Rules.SupSub
    UnaryRule = Rules.Unary

    local exponent_token_content = mock_tokenizer_module.variable + mock_tokenizer_module.number + (P"expComplex" / function() return {type="complex_exponent_placeholder"} end)

    test_grammar_table_definition = {
      "TestEntryPoint",
      TestEntryPoint = UnaryRule * -P(1),

      AtomBase = mock_tokenizer_module.matrix_placeholder +
                 mock_tokenizer_module.vector_placeholder +
                 (mock_tokenizer_module.lparen * C(R("az")) * P("+") * C(R("az")) * mock_tokenizer_module.rparen / function(v1, v2) return base_node(v1 .. "+" .. v2, "group_placeholder") end) +
                 (mock_tokenizer_module.lbrace * mock_tokenizer_module.space * exponent_token_content * mock_tokenizer_module.space * mock_tokenizer_module.rbrace) +
                 exponent_token_content,

      Expression = V("TestEntryPoint")
    }
    compiled_test_grammar = P(test_grammar_table_definition)
  end)

  after_each(function()
    for _, name in ipairs(modules_to_reset) do
      package.loaded[name] = nil
    end
  end)

  local function parse_input(input_str)
    assert(compiled_test_grammar, "Test grammar was not compiled for this test run.")
    return lpeg.match(compiled_test_grammar, input_str)
  end

  describe("Valid Transpose Operations", function()
    it("should parse MatrixA^T as transpose", function()
      local input = "MatrixA^T"
      local expected = mock_ast_module.create_transpose_node(base_node("A", "matrix"))
      assert.are.same(expected, parse_input(input))
    end)

    it("should parse MatrixB^{T} as transpose", function()
      local input = "MatrixB^{T}"
      local expected = mock_ast_module.create_transpose_node(base_node("B", "matrix"))
      assert.are.same(expected, parse_input(input))
    end)

    it("should parse MatrixC^{\\intercal} as transpose", function()
      local input = "MatrixC^{intercal}"
      local expected = mock_ast_module.create_transpose_node(base_node("C", "matrix"))
      assert.are.same(expected, parse_input(input))
    end)

    it("should parse \\vec{v}^T as transpose", function()
      local input = "\\vec{v}^T"
      local expected = mock_ast_module.create_transpose_node(base_node("v", "symbolic_vector"))
      assert.are.same(expected, parse_input(input))
    end)

     it("should parse (a+b)^T for a grouped expression (assuming group is matrix-like)", function()
        local original_atom_base = test_grammar_table_definition.AtomBase
        local exponent_token_content = mock_tokenizer_module.variable + mock_tokenizer_module.number
        test_grammar_table_definition.AtomBase =
            (mock_tokenizer_module.lparen * C(R("az")) * P("+") * C(R("az")) * mock_tokenizer_module.rparen / function(v1, v2) return base_node(v1 .. "+" .. v2, "matrix") end) +
            mock_tokenizer_module.matrix_placeholder +
            mock_tokenizer_module.vector_placeholder +
            (mock_tokenizer_module.lbrace * mock_tokenizer_module.space * exponent_token_content * mock_tokenizer_module.space * mock_tokenizer_module.rbrace) +
            exponent_token_content
        compiled_test_grammar = P(test_grammar_table_definition)

        local input = "(a+b)^T"
        local expected = mock_ast_module.create_transpose_node(base_node("a+b", "matrix"))
        assert.are.same(expected, parse_input(input))

        test_grammar_table_definition.AtomBase = original_atom_base
        compiled_test_grammar = P(test_grammar_table_definition)
    end)
  end)

  describe("Valid Inverse Operations", function()
    it("should parse MatrixA^{-1} as inverse", function()
      local input = "MatrixA^{-1}"
      local expected = mock_ast_module.create_inverse_node(base_node("A", "matrix"))
      assert.are.same(expected, parse_input(input))
    end)

    it("should parse MatrixB ^ { -1 } as inverse (with spaces)", function()
      local input = "MatrixB ^ { -1 }"
      local expected = mock_ast_module.create_inverse_node(base_node("B", "matrix"))
      assert.are.same(expected, parse_input(input))
    end)

    it("should parse (a+b)^{-1} for a grouped expression (assuming matrix-like)", function()
        local original_atom_base = test_grammar_table_definition.AtomBase
        local exponent_token_content = mock_tokenizer_module.variable + mock_tokenizer_module.number
        test_grammar_table_definition.AtomBase =
            (mock_tokenizer_module.lparen * C(R("az")) * P("+") * C(R("az")) * mock_tokenizer_module.rparen / function(v1, v2) return base_node(v1 .. "+" .. v2, "matrix") end) +
             mock_tokenizer_module.matrix_placeholder +
            (mock_tokenizer_module.lbrace * mock_tokenizer_module.space * exponent_token_content * mock_tokenizer_module.space * mock_tokenizer_module.rbrace) +
            exponent_token_content
        compiled_test_grammar = P(test_grammar_table_definition)

        local input = "(a+b)^{-1}"
        local expected = mock_ast_module.create_inverse_node(base_node("a+b", "matrix"))
        assert.are.same(expected, parse_input(input))

        test_grammar_table_definition.AtomBase = original_atom_base
        compiled_test_grammar = P(test_grammar_table_definition)
    end)
  end)

  describe("Standard Superscript/Power Operations", function()
    it("should parse x^2 as superscript", function()
      local input = "x^2"
      local expected = mock_ast_module.create_superscript_node(base_node("x", "variable"), base_node(2, "number"))
      assert.are.same(expected, parse_input(input))
    end)

    it("should parse y^{abc} as superscript (variable exponent)", function()
      local input = "y^{abc}"
      local expected = mock_ast_module.create_superscript_node(base_node("y", "variable"), base_node("abc", "variable"))
      assert.are.same(expected, parse_input(input))
    end)

    it("should parse (a+b)^n as superscript", function()
      local input = "(a+b)^n"
      local expected = mock_ast_module.create_superscript_node(base_node("a+b", "group_placeholder"), base_node("n", "variable"))
      assert.are.same(expected, parse_input(input))
    end)

    it("should parse MatrixA^2 as matrix power (superscript)", function()
      local input = "MatrixA^2"
      local expected = mock_ast_module.create_superscript_node(base_node("A", "matrix"), base_node(2, "number"))
      assert.are.same(expected, parse_input(input))
    end)

     it("should parse MatrixA^{3} as matrix power (superscript)", function()
      local input = "MatrixA^{3}"
      local expected = mock_ast_module.create_superscript_node(base_node("A", "matrix"), base_node(3, "number"))
      assert.are.same(expected, parse_input(input))
    end)

    it("should parse x^{-1} (scalar inverse) as superscript", function()
      local input = "x^{-1}"
      local expected = mock_ast_module.create_superscript_node(base_node("x", "variable"), base_node(-1, "number"))
      assert.are.same(expected, parse_input(input))
    end)

    it("should parse \\vec{v}^2 as superscript (vector to power)", function()
      local input = "\\vec{v}^2"
      local expected = mock_ast_module.create_superscript_node(base_node("v", "symbolic_vector"), base_node(2, "number"))
      assert.are.same(expected, parse_input(input))
    end)
  end)

  describe("Standard Subscript Operations", function()
    it("should parse x_i as subscript", function()
      local input = "x_i"
      local expected = mock_ast_module.create_subscript_node(base_node("x", "variable"), base_node("i", "variable"))
      assert.are.same(expected, parse_input(input))
    end)

    it("should parse MatrixA_{12} as subscript", function()
      local input = "MatrixA_{12}"
      local expected = mock_ast_module.create_subscript_node(base_node("A", "matrix"), base_node(12, "number"))
      assert.are.same(expected, parse_input(input))
    end)

     it("should parse \\vec{v}_{j} as subscript", function()
      local input = "\\vec{v}_{j}"
      local expected = mock_ast_module.create_subscript_node(base_node("v", "symbolic_vector"), base_node("j", "variable"))
      assert.are.same(expected, parse_input(input))
    end)
  end)

  describe("Unary integration", function()
    it("should parse -MatrixA^T as unary minus of transpose",function()
      local input = "-MatrixA^T"
      local transpose_node = mock_ast_module.create_transpose_node(base_node("A", "matrix"))
      local expected = mock_ast_module.create_unary_operation_node("-", transpose_node)
      assert.are.same(expected, parse_input(input))
    end)

    it("should parse +x^2 as unary plus of superscript", function()
       local input = "+x^2"
       local super_node = mock_ast_module.create_superscript_node(base_node("x", "variable"), base_node(2, "number"))
       local expected = mock_ast_module.create_unary_operation_node("+", super_node)
       assert.are.same(expected, parse_input(input))
    end)
  end)

  describe("Edge Cases and Invalid Syntax", function()
    it("should parse scalar^{-1} as superscript, not matrix inverse", function()
      local input = "s^{-1}"
      local expected = mock_ast_module.create_superscript_node(base_node("s", "variable"), base_node(-1, "number"))
      assert.are.same(expected, parse_input(input))
    end)

    it("should parse vector^T_i (transpose of vector, then subscript) - assuming (vec^T)_i", function()
      local input = "\\vec{v}^T_i"
      local expected_transpose = mock_ast_module.create_transpose_node(base_node("v", "symbolic_vector"))
      local expected_subscript = mock_ast_module.create_subscript_node(expected_transpose, base_node("i", "variable"))

      local result = parse_input(input)
      assert.are.same(expected_subscript, result)
    end)

    it("should not parse A^TInv (invalid exponent for transpose/inverse)", function()
      local input = "MatrixA^TInv"
      local expected = mock_ast_module.create_superscript_node(base_node("A", "matrix"), base_node("TInv", "variable"))
      assert.are.same(expected, parse_input(input))
    end)

    it("should not parse MatrixA^-T (invalid exponent for inverse/transpose)", function()
        local original_atom_base = test_grammar_table_definition.AtomBase
        local exponent_token_content = (P("-T") / function() return {type="negated_T_literal"} end) + mock_tokenizer_module.variable + mock_tokenizer_module.number
        test_grammar_table_definition.AtomBase =
            mock_tokenizer_module.matrix_placeholder +
            mock_tokenizer_module.vector_placeholder +
            (mock_tokenizer_module.lbrace * mock_tokenizer_module.space * exponent_token_content * mock_tokenizer_module.space * mock_tokenizer_module.rbrace) +
            exponent_token_content
        compiled_test_grammar = P(test_grammar_table_definition)

        local input = "MatrixA^-T"
        local expected_exponent = {type="negated_T_literal"}
        local expected = mock_ast_module.create_superscript_node(base_node("A", "matrix"), expected_exponent)
        assert.are.same(expected, parse_input(input))

        test_grammar_table_definition.AtomBase = original_atom_base
        compiled_test_grammar = P(test_grammar_table_definition)
    end)

    it("should parse chained superscripts correctly e.g. x^2^3 (right-associative for ^)", function()
        local input = "x^2^3"
        local inner_super = mock_ast_module.create_superscript_node(base_node("x", "variable"), base_node(2, "number"))
        local expected = mock_ast_module.create_superscript_node(inner_super, base_node(3, "number"))
        assert.are.same(expected, parse_input(input))
    end)
  end)
end)
