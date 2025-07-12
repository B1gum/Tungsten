-- tests/unit/domains/linear_algebra/rules/matrix_spec.lua
-- Unit tests for the matrix parsing rule.
---------------------------------------------------------------------

package.path = './lua/?.lua;./lua/?/init.lua;' .. package.path

local lpeg = require "lpeglabel"
local P, C, R, S = lpeg.P, lpeg.C, lpeg.R, lpeg.S

local MatrixRule

local mock_tokenizer_module
local mock_ast_module
local modules_to_reset = {
  "tungsten.domains.linear_algebra.rules.matrix",
  "tungsten.core.tokenizer",
  "tungsten.core.ast",
}

local test_grammar_table_definition
local compiled_test_grammar

local function placeholder_expr_node(val_str)
  return { type = "expression_placeholder", value = val_str }
end

describe("Linear Algebra Matrix Rule: tungsten.domains.linear_algebra.rules.matrix", function()

  before_each(function()
    for _, name in ipairs(modules_to_reset) do
      package.loaded[name] = nil
    end

    mock_tokenizer_module = {
      space = S(" \t\n\r")^0,
      matrix_env_name_capture = C(P("pmatrix") + P("bmatrix") + P("vmatrix")),
      ampersand = P("&") / function() return { type = "ampersand" } end,
      double_backslash = P("\\\\") / function() return { type = "double_backslash" } end,
      number = C(R("09")^1) / function(s) return placeholder_expr_node("num:" .. s) end,
      variable = C(R("az")^1) / function(s) return placeholder_expr_node("var:" .. s) end,
    }

    package.loaded["tungsten.core.tokenizer"] = mock_tokenizer_module

    mock_ast_module = {
      create_matrix_node = function(rows_table, env_type)
        return {
          type = "matrix",
          env_type = env_type,
          rows = rows_table
        }
      end
    }
    package.loaded["tungsten.core.ast"] = mock_ast_module

    MatrixRule = require("tungsten.domains.linear_algebra.rules.matrix")

    test_grammar_table_definition = {
      "TestEntryPoint",
      TestEntryPoint = MatrixRule * -P(1),
      Expression = mock_tokenizer_module.number + mock_tokenizer_module.variable
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
    return lpeg.match(compiled_test_grammar, input_str)
  end

  describe("Valid Matrix Structures", function()
    it("should parse a simple 1x1 pmatrix: \\begin{pmatrix} 1 \\end{pmatrix}", function()
      local input = "\\begin{pmatrix} 1 \\end{pmatrix}"
      local expected_ast = {
        type = "matrix",
        env_type = "pmatrix",
        rows = {
          { placeholder_expr_node("num:1") }
        }
      }
      local parsed = parse_input(input)
      assert.are.same(expected_ast, parsed)
    end)

    it("should parse a 2x1 pmatrix: \\begin{pmatrix} 1 \\\\ 2 \\end{pmatrix}", function()
      local input = "\\begin{pmatrix} 1 \\\\ 2 \\end{pmatrix}"
      local expected_ast = {
        type = "matrix",
        env_type = "pmatrix",
        rows = {
          { placeholder_expr_node("num:1") },
          { placeholder_expr_node("num:2") }
        }
      }
      assert.are.same(expected_ast, parse_input(input))
    end)

    it("should parse a 1x2 pmatrix: \\begin{pmatrix} 1 & a \\end{pmatrix}", function()
      local input = "\\begin{pmatrix} 1 & a \\end{pmatrix}"
      local expected_ast = {
        type = "matrix",
        env_type = "pmatrix",
        rows = {
          { placeholder_expr_node("num:1"), placeholder_expr_node("var:a") }
        }
      }
      assert.are.same(expected_ast, parse_input(input))
    end)

    it("should parse a 2x2 bmatrix: \\begin{bmatrix} 1 & a \\\\ b & 2 \\end{bmatrix}", function()
      local input = "\\begin{bmatrix} 1 & a \\\\ b & 2 \\end{bmatrix}"
      local expected_ast = {
        type = "matrix",
        env_type = "bmatrix",
        rows = {
          { placeholder_expr_node("num:1"), placeholder_expr_node("var:a") },
          { placeholder_expr_node("var:b"), placeholder_expr_node("num:2") }
        }
      }
      assert.are.same(expected_ast, parse_input(input))
    end)

    it("should parse a 3x3 vmatrix with varied spacing: \\begin{vmatrix} 1&2&3 \\\\ 4 & 5 & 6 \\\\ 7  &  8  &  9 \\end{vmatrix}", function()
      local input = "\\begin{vmatrix} 1&2&3 \\\\ 4 & 5 & 6 \\\\ 7  &  8  &  9 \\end{vmatrix}"
      local expected_ast = {
        type = "matrix",
        env_type = "vmatrix",
        rows = {
          { placeholder_expr_node("num:1"), placeholder_expr_node("num:2"), placeholder_expr_node("num:3") },
          { placeholder_expr_node("num:4"), placeholder_expr_node("num:5"), placeholder_expr_node("num:6") },
          { placeholder_expr_node("num:7"), placeholder_expr_node("num:8"), placeholder_expr_node("num:9") }
        }
      }
      assert.are.same(expected_ast, parse_input(input))
    end)

    it("should parse a matrix with a trailing double backslash before end (common in some LaTeX editors)", function()
      local input = "\\begin{pmatrix} 1 \\\\ 2 \\\\ \\end{pmatrix}"
      local input_complex = "\\begin{pmatrix} a & b \\\\ c & d \\end{pmatrix}"
      local expected_complex = {
        type = "matrix",
        env_type = "pmatrix",
        rows = {
          { placeholder_expr_node("var:a"), placeholder_expr_node("var:b") },
          { placeholder_expr_node("var:c"), placeholder_expr_node("var:d") }
        }
      }
      assert.are.same(expected_complex, parse_input(input_complex))
    end)

  end)

  describe("Invalid Matrix Structures", function()
    it("should not parse if \\begin{env} is missing: a & b \\\\ c & d \\end{pmatrix}", function()
      local input = "a & b \\\\ c & d \\end{pmatrix}"
      assert.is_nil(parse_input(input))
    end)

    it("should not parse if \\end{env} is missing: \\begin{pmatrix} a & b \\\\ c & d", function()
      local input = "\\begin{pmatrix} a & b \\\\ c & d"
      assert.is_nil(parse_input(input))
    end)

    it("should not parse if environment types mismatch: \\begin{pmatrix} 1 \\end{bmatrix}", function()

      local input = "\\begin{pmatrix} 1 \\end{bmatrix}"
      assert.is_nil(parse_input(input), "Matrix with mismatched begin/end environments should not parse.")
    end)

    it("should not parse an empty body: \\begin{pmatrix} \\end{pmatrix}", function()
      local input = "\\begin{pmatrix} \\end{pmatrix}"
      assert.is_nil(parse_input(input))
    end)

    it("should not parse if a row starts with & (empty first element): \\begin{pmatrix} & 1 \\end{pmatrix}", function()
      local input = "\\begin{pmatrix} & 1 \\end{pmatrix}"
      assert.is_nil(parse_input(input))
    end)

    it("should not parse if a row ends with & (empty last element): \\begin{pmatrix} 1 & \\end{pmatrix}", function()
      local input = "\\begin{pmatrix} 1 & \\end{pmatrix}"
      assert.is_nil(parse_input(input))
    end)

    it("should not parse if a row separator is missing between rows: \\begin{pmatrix} 1 \\\\ 2 3 \\end{pmatrix}", function()
      local input = "\\begin{pmatrix} 1 \\\\ 2 3 \\end{pmatrix}"
      assert.is_nil(parse_input(input))
    end)

    it("should not parse with two consecutive row separators: \\begin{pmatrix} 1 \\\\ \\\\ 2 \\end{pmatrix}", function()
      local input = "\\begin{pmatrix} 1 \\\\ \\\\ 2 \\end{pmatrix}"
      assert.is_nil(parse_input(input))
    end)

    it("should correctly parse a matrix with a trailing row separator", function()
      local input = "\\begin{pmatrix} 1 \\\\ 2 \\\\ \\end{pmatrix}"
      local expected_ast = {
        type = "matrix",
        env_type = "pmatrix",
        rows = {
          { placeholder_expr_node("num:1") },
          { placeholder_expr_node("num:2") }
        }
      }
      local parsed = parse_input(input)
      assert.are.same(expected_ast, parsed, "Matrix with trailing row separator should parse correctly.")
    end)
  end)
end)
