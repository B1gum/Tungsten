-- In tungsten/lua/tungsten/domains/linear_algebra/rules/matrix.lua

local lpeg = require "lpeglabel"
local P, Ct, V = lpeg.P, lpeg.Ct, lpeg.V

local tk = require "tungsten.core.tokenizer"
local ast = require "tungsten.core.ast"
local space = tk.space

local matrix_env_name_pattern = tk.matrix_env_name_capture
local matrix_begin_pattern = P("\\begin{") * space * matrix_env_name_pattern * space * P("}")
local matrix_end_pattern   = P("\\end{") * space * matrix_env_name_pattern * space * P("}")

local MatrixElement = V("Expression")

local MatrixRowWithSeparators = Ct(
    MatrixElement * (space * tk.ampersand * space * MatrixElement)^0
)
local MatrixRow = MatrixRowWithSeparators / function(captures)
    local elements_only = {}
    if type(captures) == "table" then
        for _, item in ipairs(captures) do
            if type(item) == "table" and item.type ~= "ampersand" then
                table.insert(elements_only, item)
            end
        end
    end
    return elements_only
end

local MatrixContentLoop = MatrixRow * (space * tk.double_backslash * space * MatrixRow)^0
local OptionalTrailingSeparatorPattern = (space * tk.double_backslash * space)^-1

local MatrixBodyWithSeparators = Ct(MatrixContentLoop * OptionalTrailingSeparatorPattern)

local MatrixBody = MatrixBodyWithSeparators / function(captures)
    local rows_only = {}
    if type(captures) == "table" then
        for _, item in ipairs(captures) do
            if type(item) == "table" and item.type ~= "double_backslash" then
                table.insert(rows_only, item)
            end
        end
    end
    return rows_only
end


local MatrixRule = Ct(
  matrix_begin_pattern * space *
  MatrixBody *
  space *
  matrix_end_pattern
) / function(captures)
  local begin_env_type = captures[1]
  local actual_matrix_rows = captures[2]
  local end_env_type = captures[3]

  if not (type(begin_env_type) == "string" and begin_env_type ~= "") then return nil end
  if not (type(end_env_type) == "string" and end_env_type ~= "") then return nil end
  if begin_env_type ~= end_env_type then return nil end
  if type(actual_matrix_rows) ~= "table" then return nil end

    for _, row_table in ipairs(actual_matrix_rows) do
        if type(row_table) ~= "table" then
            if #row_table == 0 then
                return nil
            end
        end
        if #row_table == 0 and #actual_matrix_rows == 1 and (row_table[1] == nil and not next(row_table)) then
            return nil
        end

        for _, element_ast in ipairs(row_table) do
            if type(element_ast) ~= "table" or not element_ast.type then
                return nil
            end
        end
  end

  if #actual_matrix_rows == 0 then
      return nil
  end

  return ast.create_matrix_node(actual_matrix_rows, begin_env_type)
end

return MatrixRule

