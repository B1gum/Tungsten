--------------------------------------------------------------------------------
-- extractors.lua
-- Main module for breaking the input into the expression and other
-- command-specific syntax.
--------------------------------------------------------------------------------

local M = {}

-- Function to extract main expression and curly specifications
function M.extract_main_and_curly(selection)
  local last_mainExpr = selection
  local last_curlySpec = nil
  local balance = 0
  local last_open = 0

  for i = 1, #selection do
    local c = selection:sub(i, i)
    if c == "{" then
      balance = balance + 1
      if balance == 1 then
        last_open = i
      end
    elseif c == "}" then
      balance = balance - 1
      if balance == 0 and last_open > 0 then
        local mainExpr = selection:sub(1, last_open -1):match("^%s*(.-)%s*$")
        local curlySpec = selection:sub(last_open +1, i -1):match("^%s*(.-)%s*$")
        last_mainExpr = mainExpr
        last_curlySpec = curlySpec
      end
    end
  end

  return last_mainExpr, last_curlySpec
end

-- Function to extract expression and range specifications
function M.extract_expr_and_range(mainExpr)
  mainExpr = mainExpr:match("^%s*(.-)%s*$")

  local last_open = mainExpr:match(".*()%[")
  local last_close = mainExpr:match("()%]")

  if last_open and last_close and last_close > last_open then
    local exprPart = mainExpr:sub(1, last_open - 1):match("^%s*(.-)%s*$")
    local rangeSpec = mainExpr:sub(last_open + 1, last_close - 1):match("^%s*(.-)%s*$")
    return exprPart, rangeSpec
  else
    return mainExpr, nil
  end
end

-- Function to extract equation and variable
function M.extract_equation_and_variable(selection)
  local parts = require("tungsten.utils.string_utils").split_by_comma(selection)
  if #parts < 2 then
    return nil, nil, "Input must be in the format: equation, variable"
  end
  local equation = parts[1]:match("^%s*(.-)%s*$")
  local variable = parts[2]:match("^%s*(.-)%s*$")
  if not equation or not variable or variable == "" then
    return nil, nil, "Failed to parse equation and variable. Ensure format: equation, variable"
  end
  if not equation:find(variable) then
    return nil, nil, "Variable '" .. variable .. "' not found in the equation."
  end
  return equation, variable, nil
end

-- Function to extract unique variables from a list of equations
function M.extract_variables(equations)
  local vars = {}
  local knownFunctions = {
    ["Sin"] = true, ["Cos"] = true, ["Tan"] = true, ["Exp"] = true,
    ["Log"] = true, ["Pi"] = true, ["Alpha"] = true, ["Tau"] = true,
    ["Beta"] = true, ["D"] = true, ["Integrate"] = true, ["Plot"] = true,
    ["Solve"] = true, ["FullSimplify"] = true, ["Sqrt"] = true, ["NSolve"] = true
  }

  for _, eq in ipairs(equations) do
    for var in eq:gmatch("[A-Za-z]+") do
      if not knownFunctions[var] then
        vars[var] = true
      end
    end
  end

  local varList = {}
  for var, _ in pairs(vars) do
    table.insert(varList, var)
  end
  return varList
end

return M
