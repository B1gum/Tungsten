-- lua/tungsten/domains/linear_algebra/wolfram_handlers.lua
-- Wolfram Language handlers for linear algebra operations
---------------------------------------------------------------------

local M = {}

M.handlers = {
  matrix = function(node, recur_render)
    local rendered_rows = {}
    for _, row_elements in ipairs(node.rows) do
      local rendered_elements_in_row = {}
      for _, element_node in ipairs(row_elements) do
        table.insert(rendered_elements_in_row, recur_render(element_node))
      end
      table.insert(rendered_rows, "{" .. table.concat(rendered_elements_in_row, ", ") .. "}")
    end
    return "{" .. table.concat(rendered_rows, ", ") .. "}"
  end,

  vector = function(node, recur_render)
    local rendered_elements = {}
    for _, element_node in ipairs(node.elements) do
      table.insert(rendered_elements, recur_render(element_node))
    end
    return "{" .. table.concat(rendered_elements, ", ") .. "}"
  end,

  symbolic_vector = function(node, recur_render)
    return recur_render(node.name_expr)
  end,

  determinant = function(node, recur_render)
    return ("Det[%s]"):format(recur_render(node.expression))
  end,

  transpose = function(node, recur_render)
    return ("Transpose[%s]"):format(recur_render(node.expression))
  end,

  inverse = function(node, recur_render)
    return ("Inverse[%s]"):format(recur_render(node.expression))
  end,

  dot_product = function(node, recur_render)
    local left_str = recur_render(node.left)
    local right_str = recur_render(node.right)
    return ("Dot[%s, %s]"):format(left_str, right_str)
  end,

  cross_product = function(node, recur_render)
    local left_str = recur_render(node.left)
    local right_str = recur_render(node.right)
    return ("Cross[%s, %s]"):format(left_str, right_str)
  end,

  norm = function(node, recur_render)
    local expr_str = recur_render(node.expression)
    if node.p_value then
      local p_val_str = recur_render(node.p_value)
      return ("Norm[%s, %s]"):format(expr_str, p_val_str)
    else
      return ("Norm[%s]"):format(expr_str)
    end
  end,

  matrix_power = function(node, recur_render)
    local base_str = recur_render(node.base)
    local exp_str = recur_render(node.exponent)
    return ("MatrixPower[%s, %s]"):format(base_str, exp_str)
  end,

  identity_matrix = function(node, recur_render)
    local dim_str = recur_render(node.dimension)
    return ("IdentityMatrix[%s]"):format(dim_str)
  end,

  zero_vector_matrix = function(node, recur_render)
    local dim_spec_str = recur_render(node.dimensions)
    return ("ConstantArray[0, %s]"):format(dim_spec_str)
  end,

  gauss_eliminate = function(node, recur_render)
    local matrix_str = recur_render(node.expression)
    return ("RowReduce[%s]"):format(matrix_str)
  end,
}

return M
