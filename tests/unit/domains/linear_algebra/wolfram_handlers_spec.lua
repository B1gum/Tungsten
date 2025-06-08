-- tests/unit/domains/linear_algebra/wolfram_handlers_spec.lua
-- Unit tests for the Wolfram handlers in the linear algebra domain.
---------------------------------------------------------------------

package.path = './lua/?.lua;./lua/?/init.lua;' .. package.path

local spy = require 'luassert.spy'
local linear_algebra_wolfram_handlers

describe("Tungsten Linear Algebra Domain Wolfram Handlers", function()
  local handlers
  local mock_recur_render

  local function ast_node(type, props)
    props = props or {}
    props.type = type
    return props
  end

  before_each(function()
    package.loaded["tungsten.domains.linear_algebra.wolfram_handlers"] = nil
    linear_algebra_wolfram_handlers = require("tungsten.domains.linear_algebra.wolfram_handlers")
    handlers = linear_algebra_wolfram_handlers.handlers

    mock_recur_render = spy.new(function(child_node)
      if not child_node or type(child_node) ~= "table" then
        return tostring(child_node)
      end

      if child_node.type == "number" then return tostring(child_node.value) end
      if child_node.type == "variable" then return child_node.name end
      if child_node.type == "symbol" then
        if child_node.name == "infinity" then return "Infinity" end
        return child_node.name
      end
      if child_node.type == "matrix_placeholder" then return child_node.name or "GenericMatrix" end
      if child_node.type == "vector_placeholder" then return child_node.name or "GenericVector" end
      if child_node.type == "expr_placeholder" then return child_node.content or "GenericExpression" end

      return "rendered(" .. child_node.type .. ":" .. (child_node.name or child_node.value or "complex_child") .. ")"
    end)
  end)

  describe("matrix handler", function()
    it("should correctly render a 2x2 matrix", function()
      local node = ast_node("matrix", {
        rows = {
          { ast_node("number", { value = 1 }), ast_node("variable", { name = "a" }) },
          { ast_node("variable", { name = "b" }), ast_node("number", { value = 2 }) },
        }
      })
      local result = handlers.matrix(node, mock_recur_render)
      assert.are.equal("{{1, a}, {b, 2}}", result)
      assert.spy(mock_recur_render).was.called_with(ast_node("number", { value = 1 }))
      assert.spy(mock_recur_render).was.called_with(ast_node("variable", { name = "a" }))
      assert.spy(mock_recur_render).was.called_with(ast_node("variable", { name = "b" }))
      assert.spy(mock_recur_render).was.called_with(ast_node("number", { value = 2 }))
    end)

    it("should correctly render a 1x3 matrix (row vector)", function()
      local node = ast_node("matrix", {
        rows = {
          { ast_node("number", { value = 1 }), ast_node("number", { value = 2 }), ast_node("number", { value = 3 }) },
        }
      })
      local result = handlers.matrix(node, mock_recur_render)
      assert.are.equal("{{1, 2, 3}}", result)
    end)

    it("should correctly render a 3x1 matrix (column vector like)", function()
      local node = ast_node("matrix", {
        rows = {
          { ast_node("variable", { name = "x" }) },
          { ast_node("variable", { name = "y" }) },
          { ast_node("variable", { name = "z" }) },
        }
      })
      local result = handlers.matrix(node, mock_recur_render)
      assert.are.equal("{{x}, {y}, {z}}", result)
    end)
  end)

  describe("vector handler", function()
    it("should correctly render a simple vector", function()
      local node = ast_node("vector", {
        elements = {
          ast_node("variable", { name = "v1" }),
          ast_node("number", { value = 5 }),
          ast_node("variable", { name = "v3" }),
        },
        orientation = "column"
      })
      local result = handlers.vector(node, mock_recur_render)
      assert.are.equal("{v1, 5, v3}", result)
      assert.spy(mock_recur_render).was.called_with(ast_node("variable", { name = "v1" }))
      assert.spy(mock_recur_render).was.called_with(ast_node("number", { value = 5 }))
    end)
  end)

  describe("symbolic_vector handler", function()
    it("should render the name_expr of the symbolic vector", function()
      local name_node = ast_node("variable", { name = "myVec" })
      local node = ast_node("symbolic_vector", {
        name_expr = name_node,
        command = "vec"
      })
      local result = handlers.symbolic_vector(node, mock_recur_render)
      assert.are.equal("myVec", result)
      assert.spy(mock_recur_render).was.called_with(name_node)
    end)
  end)

  describe("determinant handler", function()
    it("should correctly format Det[matrix]", function()
      local matrix_expr_node = ast_node("expr_placeholder", { content = "M" })
      local node = ast_node("determinant", { expression = matrix_expr_node })
      local result = handlers.determinant(node, mock_recur_render)
      assert.are.equal("Det[M]", result)
      assert.spy(mock_recur_render).was.called_with(matrix_expr_node)
    end)
  end)

  describe("transpose handler", function()
    it("should correctly format Transpose[matrix]", function()
      local matrix_expr_node = ast_node("expr_placeholder", { content = "A" })
      local node = ast_node("transpose", { expression = matrix_expr_node })
      local result = handlers.transpose(node, mock_recur_render)
      assert.are.equal("Transpose[A]", result)
      assert.spy(mock_recur_render).was.called_with(matrix_expr_node)
    end)
  end)

  describe("inverse handler", function()
    it("should correctly format Inverse[matrix]", function()
      local matrix_expr_node = ast_node("expr_placeholder", { content = "B" })
      local node = ast_node("inverse", { expression = matrix_expr_node })
      local result = handlers.inverse(node, mock_recur_render)
      assert.are.equal("Inverse[B]", result)
      assert.spy(mock_recur_render).was.called_with(matrix_expr_node)
    end)
  end)

  describe("dot_product handler", function()
    it("should correctly format Dot[vec1, vec2]", function()
      local vec1_node = ast_node("vector_placeholder", { name = "u" })
      local vec2_node = ast_node("vector_placeholder", { name = "v" })
      local node = ast_node("dot_product", { left = vec1_node, right = vec2_node })
      local result = handlers.dot_product(node, mock_recur_render)
      assert.are.equal("Dot[u, v]", result)
      assert.spy(mock_recur_render).was.called_with(vec1_node)
      assert.spy(mock_recur_render).was.called_with(vec2_node)
    end)
  end)

  describe("cross_product handler", function()
    it("should correctly format Cross[vec1, vec2]", function()
      local vec1_node = ast_node("vector_placeholder", { name = "a" })
      local vec2_node = ast_node("vector_placeholder", { name = "b" })
      local node = ast_node("cross_product", { left = vec1_node, right = vec2_node })
      local result = handlers.cross_product(node, mock_recur_render)
      assert.are.equal("Cross[a, b]", result)
      assert.spy(mock_recur_render).was.called_with(vec1_node)
      assert.spy(mock_recur_render).was.called_with(vec2_node)
    end)
  end)

  describe("norm handler", function()
    it("should correctly format Norm[expr] (default 2-norm)", function()
      local expr_node = ast_node("vector_placeholder", { name = "x" })
      local node = ast_node("norm", { expression = expr_node, p_value = nil })
      local result = handlers.norm(node, mock_recur_render)
      assert.are.equal("Norm[x]", result)
      assert.spy(mock_recur_render).was.called_with(expr_node)
    end)

    it("should correctly format Norm[expr, p] for numeric p", function()
      local expr_node = ast_node("vector_placeholder", { name = "y" })
      local p_val_node = ast_node("number", { value = 1 })
      local node = ast_node("norm", { expression = expr_node, p_value = p_val_node })
      local result = handlers.norm(node, mock_recur_render)
      assert.are.equal("Norm[y, 1]", result)
      assert.spy(mock_recur_render).was.called_with(p_val_node)
    end)

    it("should correctly format Norm[expr, p] for variable p", function()
      local expr_node = ast_node("matrix_placeholder", { name = "M" })
      local p_val_node = ast_node("variable", { name = "p" })
      local node = ast_node("norm", { expression = expr_node, p_value = p_val_node })
      local result = handlers.norm(node, mock_recur_render)
      assert.are.equal("Norm[M, p]", result)
    end)

    it("should correctly format Norm[expr, Infinity]", function()
      local expr_node = ast_node("vector_placeholder", { name = "z" })
      local p_val_node = ast_node("symbol", { name = "infinity" })
      local node = ast_node("norm", { expression = expr_node, p_value = p_val_node })
      local result = handlers.norm(node, mock_recur_render)
      assert.are.equal("Norm[z, Infinity]", result)
    end)

    it("should correctly format Norm[matrix, \"Frobenius\"]", function()
      local expr_node = ast_node("matrix_placeholder", { name = "FrobMat" })
      local p_val_node = ast_node("variable", { name = "Frobenius" })
      local node = ast_node("norm", { expression = expr_node, p_value = p_val_node })
      local result = handlers.norm(node, mock_recur_render)
      assert.are.equal("Norm[FrobMat, Frobenius]", result)
    end)
  end)

  describe("matrix_power handler", function()
    it("should correctly format MatrixPower[matrix, n]", function()
      local base_node = ast_node("matrix_placeholder", { name = "MyMat" })
      local exp_node = ast_node("number", { value = 3 })
      local node = ast_node("matrix_power", { base = base_node, exponent = exp_node })
      local result = handlers.matrix_power(node, mock_recur_render)
      assert.are.equal("MatrixPower[MyMat, 3]", result)
      assert.spy(mock_recur_render).was.called_with(base_node)
      assert.spy(mock_recur_render).was.called_with(exp_node)
    end)
  end)

  describe("identity_matrix handler", function()
    it("should correctly format IdentityMatrix[n]", function()
      local dim_node = ast_node("number", { value = 4 })
      local node = ast_node("identity_matrix", { dimension = dim_node })
      local result = handlers.identity_matrix(node, mock_recur_render)
      assert.are.equal("IdentityMatrix[4]", result)
      assert.spy(mock_recur_render).was.called_with(dim_node)
    end)
  end)

  describe("zero_vector_matrix handler", function()
    it("should correctly format ConstantArray[0, n] for a vector", function()
      local dim_node = ast_node("number", { value = 3 })
      local node = ast_node("zero_vector_matrix", { dimensions = dim_node })
      local result = handlers.zero_vector_matrix(node, mock_recur_render)
      assert.are.equal("ConstantArray[0, 3]", result)
      assert.spy(mock_recur_render).was.called_with(dim_node)
    end)

    it("should correctly format ConstantArray[0, {m, n}] for a matrix", function()
      local dim_node_for_matrix = ast_node("vector", {
        elements = { ast_node("number", {value=2}), ast_node("number", {value=3}) }
      })
      mock_recur_render = spy.new(function(child_node)
        if child_node == dim_node_for_matrix then return "{2, 3}" end
        return "unexpected_child_in_zero_matrix_test"
      end)

      local node = ast_node("zero_vector_matrix", { dimensions = dim_node_for_matrix })
      local result = handlers.zero_vector_matrix(node, mock_recur_render)
      assert.are.equal("ConstantArray[0, {2, 3}]", result)
      assert.spy(mock_recur_render).was.called_with(dim_node_for_matrix)
    end)
  end)

    describe("gauss_eliminate handler", function()
    it("should correctly format RowReduce[matrix_representation]", function()
      local matrix_ast_placeholder = ast_node("matrix_placeholder", { name = "MyMatrix" })
      local gauss_node = ast_node("gauss_eliminate", { expression = matrix_ast_placeholder })

      mock_recur_render = spy.new(function(node_to_render)
        if node_to_render == matrix_ast_placeholder then
          return "RenderedMatrix"
        end
        return "unexpected_node_in_gauss_eliminate_test"
      end)

      local result = handlers.gauss_eliminate(gauss_node, mock_recur_render)
      assert.are.equal("RowReduce[RenderedMatrix]", result)
      assert.spy(mock_recur_render).was.called_with(matrix_ast_placeholder)
    end)

    it("should correctly render with a complex matrix AST", function()
        local complex_matrix_node = ast_node("matrix", {
            rows = {
                { ast_node("number", { value = 1 }), ast_node("number", { value = 2 }) },
                { ast_node("number", { value = 3 }), ast_node("number", { value = 4 }) },
            }
        })
        local gauss_node = ast_node("gauss_eliminate", {expression = complex_matrix_node})

        mock_recur_render = spy.new(function(node_to_render)
            if node_to_render == complex_matrix_node then
                return "{{1,2},{3,4}}"
            end
            return "rendered(" .. node_to_render.type .. ")"
        end)

        local result = handlers.gauss_eliminate(gauss_node, mock_recur_render)
        assert.are.equal("RowReduce[{{1,2},{3,4}}]", result)
        assert.spy(mock_recur_render).was.called_with(complex_matrix_node)
    end)
  end)

  describe("rank handler", function()
    it("should correctly format MatrixRank[matrix_representation]", function()
      local matrix_expr_node = ast_node("matrix_placeholder", { name = "MyTestMatrix" })
      local node = ast_node("rank", { expression = matrix_expr_node })

      mock_recur_render:clear()
      mock_recur_render = spy.new(function(child_node)
        if child_node == matrix_expr_node then
          return "RenderedMatrixRepresentation"
        end
        return "unexpected_child_in_rank_test"
      end)

      local result = handlers.rank(node, mock_recur_render)
      assert.are.equal("MatrixRank[RenderedMatrixRepresentation]", result)
      assert.spy(mock_recur_render).was.called_with(matrix_expr_node)
    end)

    it("should correctly render with a complex matrix AST passed to recur_render", function()
        local complex_matrix_node = ast_node("matrix", {
            rows = {
                { ast_node("number", { value = 1 }), ast_node("number", { value = 2 }) },
                { ast_node("number", { value = 3 }), ast_node("number", { value = 4 }) },
            }
        })
        local rank_node = ast_node("rank", {expression = complex_matrix_node})

        mock_recur_render:clear()
        mock_recur_render = spy.new(function(node_to_render)
            if node_to_render == complex_matrix_node then
                return "{{1,2},{3,4}}"
            end
            return "rendered_unexpected_child"
        end)

        local result = handlers.rank(rank_node, mock_recur_render)
        assert.are.equal("MatrixRank[{{1,2},{3,4}}]", result)
        assert.spy(mock_recur_render).was.called_with(complex_matrix_node)
    end)
  end)
  describe("eigenvalues handler", function()
    it("should correctly format Eigenvalues[matrix_representation]", function()
      local matrix_expr_node = ast_node("matrix_placeholder", { name = "MyEigenMatrix" })
      local node = ast_node("eigenvalues", { expression = matrix_expr_node })

      mock_recur_render:clear()
      mock_recur_render = spy.new(function(child_node)
        if child_node == matrix_expr_node then
          return "RenderedMatrixForEigen"
        end
        return "unexpected_child_in_eigenvalues_test"
      end)

      local result = handlers.eigenvalues(node, mock_recur_render)
      assert.are.equal("Eigenvalues[RenderedMatrixForEigen]", result)
      assert.spy(mock_recur_render).was.called_with(matrix_expr_node)
    end)

    it("should correctly render with a complex matrix AST passed to recur_render", function()
        local complex_matrix_node = ast_node("matrix", {
            rows = {
                { ast_node("number", { value = 2 }), ast_node("number", { value = -1 }) },
                { ast_node("number", { value = 1 }), ast_node("number", { value = 2 }) },
            }
        })
        local eigenvalues_node = ast_node("eigenvalues", {expression = complex_matrix_node})

        mock_recur_render:clear()
        mock_recur_render = spy.new(function(node_to_render)
            if node_to_render == complex_matrix_node then
                return "{{2,-1},{1,2}}"
            end
            return "rendered_unexpected_child"
        end)

        local result = handlers.eigenvalues(eigenvalues_node, mock_recur_render)
        assert.are.equal("Eigenvalues[{{2,-1},{1,2}}]", result)
        assert.spy(mock_recur_render).was.called_with(complex_matrix_node)
    end)
  end)
end)
