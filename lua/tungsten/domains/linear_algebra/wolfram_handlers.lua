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

  vector_list = function(node, recur_render)
    local rendered_vectors = {}
    for _, vector_node_in_list in ipairs(node.vectors) do
        if vector_node_in_list.type == "matrix" then
            local rows_as_vectors = {}
            for _, row in ipairs(vector_node_in_list.rows) do
                local rendered_row_elements = {}
                for _, el in ipairs(row) do
                    table.insert(rendered_row_elements, recur_render(el))
                end
                if #row == 1 then
                     table.insert(rows_as_vectors, "{" .. table.concat(rendered_row_elements, ", ") .. "}")
                else
                    table.insert(rows_as_vectors, "{" .. table.concat(rendered_row_elements, ", ") .. "}")
                    break
                end
            end
            table.insert(rendered_vectors, recur_render(vector_node_in_list))

        else
            table.insert(rendered_vectors, recur_render(vector_node_in_list))
        end
    end
    return "{" .. table.concat(rendered_vectors, ", ") .. "}"
  end,

  linear_independent_test = function(node, recur_render)
    local target_ast = node.target
    local rendered_argument_list

    if target_ast.type == "matrix" then
      rendered_argument_list = recur_render(target_ast)
    elseif target_ast.type == "vector_list" then
      local vectors_for_wolfram = {}
      for _, vec_node in ipairs(target_ast.vectors) do

        if vec_node.type == "matrix" then
          local elements = {}
          if #vec_node.rows == 1 then
            for _, el_node in ipairs(vec_node.rows[1]) do
              table.insert(elements, recur_render(el_node))
            end
            table.insert(vectors_for_wolfram, "{" .. table.concat(elements, ", ") .. "}")
          elseif #vec_node.rows > 0 and #vec_node.rows[1] and #vec_node.rows[1] == 1 then
            for _, row_array in ipairs(vec_node.rows) do
              table.insert(elements, recur_render(row_array[1]))
            end
            table.insert(vectors_for_wolfram, "{" .. table.concat(elements, ", ") .. "}")
          else
            table.insert(vectors_for_wolfram, recur_render(vec_node))
          end
        else
          table.insert(vectors_for_wolfram, recur_render(vec_node))
        end
      end
      rendered_argument_list = "{" .. table.concat(vectors_for_wolfram, ", ") .. "}"
    elseif target_ast.type == "vector" or target_ast.type == "symbolic_vector" then
      rendered_argument_list = "{" .. recur_render(target_ast) .. "}"
    else
      logger.warn("Tungsten: linear_independent_test handler received unexpected AST type: " .. target_ast.type)
      rendered_argument_list = recur_render(target_ast)
    end

    return ("ResourceFunction[\"LinearlyIndependent\"][%s]"):format(rendered_argument_list)
  end,

}

return M
