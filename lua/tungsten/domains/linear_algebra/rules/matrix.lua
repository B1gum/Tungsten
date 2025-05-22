-- tungsten/lua/tungsten/domains/linear_algebra/rules/matrix.lua
local lpeg = require "lpeg"
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
            elseif type(item) ~= "table" or not item.type then
            end
        end
    end
    return elements_only
end

local MatrixBodyWithSeparators = Ct(
    MatrixRow * (space * tk.double_backslash * space * MatrixRow)^0
)
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

local OptionalTrailingBackslash = (space * tk.double_backslash * space)^-1

local MatrixRule = Ct(
  matrix_begin_pattern * space *
  MatrixBody *
  (OptionalTrailingBackslash) *
  space *
  matrix_end_pattern
) / function(captures)
  local begin_env_type = captures[1]
  local actual_matrix_rows = captures[2]
  local end_env_type = captures[3]

  if not (type(begin_env_type) == "string" and begin_env_type ~= "") then return nil end
  if not (type(end_env_type) == "string" and end_env_type ~= "") then return nil end
  if begin_env_type ~= end_env_type then return nil end
  if not (type(actual_matrix_rows) == "table") then return nil end

  for r_idx, row_table in ipairs(actual_matrix_rows) do
    if not (type(row_table) == "table") then
        if #row_table == 0 and #actual_matrix_rows > 0 then
        elseif #row_table == 0 then
            return nil
        end
    end
    if #row_table == 0 and #actual_matrix_rows == 1 and not next(row_table) then
        if #actual_matrix_rows == 1 and #row_table == 0 and not next(row_table[1]) then
            return nil
        end
    end


    for c_idx, element_ast in ipairs(row_table) do
      if not (type(element_ast) == "table" and element_ast.type) then
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
