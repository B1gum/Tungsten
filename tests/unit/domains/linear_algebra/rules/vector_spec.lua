-- tungsten/tests/unit/domains/linear_algebra/rules/vector_spec.lua

package.path = './lua/?.lua;./lua/?/init.lua;' .. package.path

local lpeg = require "lpeg"
local P, V, C, R, S, Ct = lpeg.P, lpeg.V, lpeg.C, lpeg.R, lpeg.S, lpeg.Ct

local VectorRule
local MatrixRule_module

local mock_tokenizer_module
local mock_ast_module
local modules_to_reset = {
  "tungsten.domains.linear_algebra.rules.vector",
  "tungsten.core.tokenizer",
  "tungsten.core.ast",
  "tungsten.domains.linear_algebra.rules.matrix",
}

local test_grammar_table_definition
local compiled_test_grammar

local function variable_node(name_str)
    return { type = "variable", name = name_str }
end

local function number_node(num_val)
    return { type = "number", value = num_val }
end

describe("Linear Algebra Vector Rule (Symbolic): tungsten.domains.linear_algebra.rules.vector", function()

  before_each(function()
    for _, name in ipairs(modules_to_reset) do
      package.loaded[name] = nil
    end

    local lpeg_P, lpeg_C, lpeg_S, lpeg_R = lpeg.P, lpeg.C, lpeg.S, lpeg.R

    mock_tokenizer_module = {
      space = lpeg_S(" \t\n\r")^0,
      lbrace = lpeg_P("{"),
      rbrace = lpeg_P("}"),
      variable = lpeg_C(lpeg_R("az","AZ") * (lpeg_R("az","AZ","09")^0)) / function(v_str) return variable_node(v_str) end,
      number = lpeg_C(lpeg_R("09")^1) / function(n_str) return number_node(tonumber(n_str)) end,

      matrix_env_name_capture = lpeg_C(lpeg_P("pmatrix") + lpeg_P("bmatrix") + lpeg_P("vmatrix")),
      ampersand = lpeg_P("&") / function() return {type = "ampersand_token_from_mock"} end,
      double_backslash = lpeg_P("\\\\") / function() return {type = "double_backslash_token_from_mock"} end,
    }
    package.loaded["tungsten.core.tokenizer"] = mock_tokenizer_module

    mock_ast_module = {
      create_symbolic_vector_node = function(name_expr_ast, command_str)
        return {
          type = "symbolic_vector",
          name_expr = name_expr_ast,
          command = command_str
        }
      end,
      create_subscript_node = function(base, sub)
        return { type = "subscript", base = base, subscript = sub }
      end,
      create_matrix_node = function(rows_table, env_type_str)
          return {
              type = "matrix_ast_placeholder",
              env = env_type_str,
              mock_rows = rows_table
          }
      end
    }
    package.loaded["tungsten.core.ast"] = mock_ast_module

    MatrixRule_module = require("tungsten.domains.linear_algebra.rules.matrix")
    VectorRule = require("tungsten.domains.linear_algebra.rules.vector")

    local local_mock_space = mock_tokenizer_module.space
    test_grammar_table_definition = {
      "TestEntryPoint",
      TestEntryPoint = VectorRule * -lpeg_P(1),
      Expression = ( mock_tokenizer_module.variable * lpeg_P("_") * local_mock_space * (mock_tokenizer_module.variable + mock_tokenizer_module.number) / function(b,s) return mock_ast_module.create_subscript_node(b,s) end) +
                   mock_tokenizer_module.variable +
                   mock_tokenizer_module.number,
      AtomBase = mock_tokenizer_module.variable + mock_tokenizer_module.number,
      Matrix = MatrixRule_module,
    }
    compiled_test_grammar = lpeg.P(test_grammar_table_definition)
  end)

  after_each(function()
    for _, name in ipairs(modules_to_reset) do
      package.loaded[name] = nil
    end
  end)

  local function parse_input(input_str)
    assert(compiled_test_grammar, "Test grammar was not compiled for this test run.")
    local result = lpeg.match(compiled_test_grammar, input_str)
    return result
  end

  describe("Valid \\vec and \\mathbf notations", function()
    it("should parse \\vec{a} (single variable)", function()
      local input = "\\vec{a}"
      local expected_ast = {
        type = "symbolic_vector",
        name_expr = variable_node("a"),
        command = "vec"
      }
      assert.are.same(expected_ast, parse_input(input))
    end)

    it("should parse \\mathbf{x} (single variable)", function()
      local input = "\\mathbf{x}"
      local expected_ast = {
        type = "symbolic_vector",
        name_expr = variable_node("x"),
        command = "mathbf"
      }
      assert.are.same(expected_ast, parse_input(input))
    end)

    it("should parse \\vec{AB} (multi-character variable as content)", function()
      local input = "\\vec{AB}"
      local expected_ast = {
        type = "symbolic_vector",
        name_expr = variable_node("AB"),
        command = "vec"
      }
      assert.are.same(expected_ast, parse_input(input))
    end)

    it("should parse \\mathbf{x_1} (subscripted variable as content)", function()
      local input = "\\mathbf{x_1}"
      local expected_ast = {
        type = "symbolic_vector",
        name_expr = {
            type = "subscript",
            base = variable_node("x"),
            subscript = number_node(1)
        },
        command = "mathbf"
      }
      assert.are.same(expected_ast, parse_input(input))
    end)

    it("should parse with space: \\vec{  v  }", function()
      local input = "\\vec{  v  }"
      local expected_ast = {
        type = "symbolic_vector",
        name_expr = variable_node("v"),
        command = "vec"
      }
      assert.are.same(expected_ast, parse_input(input))
    end)
  end)

  describe("Invalid notations or edge cases", function()
    it("should not parse incomplete \\vec{}", function()
      assert.is_nil(parse_input("\\vec{}"))
    end)

    it("should not parse incomplete \\vec{a", function()
      assert.is_nil(parse_input("\\vec{a"))
    end)

    it("should not parse \\vec without braces", function()
      assert.is_nil(parse_input("\\veca"))
    end)

    it("should not parse \\mathbf{} (empty content)", function()
      assert.is_nil(parse_input("\\mathbf{}"))
    end)

    it("should only parse the vector part if followed by other characters", function()
      local grammar_for_partial_match = lpeg.P{
        "TestEntryPoint",
        TestEntryPoint = VectorRule * C(P(1)^0),
        Expression = mock_tokenizer_module.variable + mock_tokenizer_module.number,
        Matrix = MatrixRule_module 
      }
      local vec_ast, remainder = lpeg.match(grammar_for_partial_match, "\\vec{a} + b")
      local expected_ast = {
        type = "symbolic_vector",
        name_expr = variable_node("a"),
        command = "vec"
      }
      assert.are.same(expected_ast, vec_ast)
      assert.are.equal("+ b", remainder)
    end)
  end)
end)
