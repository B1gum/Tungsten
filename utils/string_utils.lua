--------------------------------------------------------------------------------
-- string_utils.lua
-- Simple string-manipulation module.
--------------------------------------------------------------------------------

local M = {}

-- Function to split a string into a table based on a delimiter
function M.split(str, delimiter)
  local result = {}
  for match in (str .. delimiter):gmatch("(.-)" .. delimiter) do
    table.insert(result, match)
  end
  return result
end

-- Function to split multiple mathematical expressions separated by commas into separate expressions
function M.split_expressions(exprPart)
  local exprList = {}
  local current = ""
  local depth = 0
  for i = 1, #exprPart do
    local c = exprPart:sub(i, i)
    if c == "[" or c == "{" or c == "(" then
      depth = depth + 1
    elseif c == "]" or c == "}" or c == ")" then
      depth = depth - 1
    elseif c == "," and depth == 0 then
      table.insert(exprList, current)
      current = ""
      goto continue
    end
    current = current .. c
    ::continue::
  end
  if current ~= "" then
    table.insert(exprList, current)
  end

  for i, expr in ipairs(exprList) do
    exprList[i] = expr:gsub("^%s+", ""):gsub("%s+$", "")
  end
  return exprList
end

-- Function that splits a string by commas without considering nested structure or depth
function M.split_by_comma(str)
  local result = {}
  for part in string.gmatch(str, "([^,]+)") do
    table.insert(result, part)
  end
  return result
end

-- Constructs a single expression string from a list of multiple expressions
function M.build_multi_expr(exprList)
  if #exprList == 1 then
    return exprList[1]
  else
    return "{" .. table.concat(exprList, ", ") .. "}"
  end
end

-- Helper function to add brackets if needed
function M.bracket_if_needed(expr)
  if expr:find("[+%-]") then
    return "(" .. expr .. ")"
  else
    return expr
  end
end

return M
