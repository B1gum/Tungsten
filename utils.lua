--------------------------------------------------------------------------------
-- /config/nvim/lua/wolfram/utils.lua
-- Contains utility functions used across the plugin.
--------------------------------------------------------------------------------

local M = {}

-- Debug print function (set DEBUG to false to disable debug messages)
local DEBUG = true
local function debug_print(msg)
  if DEBUG then
    print("DEBUG: " .. msg)
  end
end

M.debug_print = debug_print

--------------------------------------------------------------------------------
-- parse_result
--------------------------------------------------------------------------------
function M.parse_result(raw_result)
  if not raw_result then
    return ""
  end
  -- Remove non-printable characters:
  raw_result = raw_result:gsub("[%z\1-\31]", "")
  -- Trim leading/trailing whitespace:
  raw_result = raw_result:match("^%s*(.-)%s*$") or raw_result
  return raw_result
end

--------------------------------------------------------------------------------
-- Helpers for splitting strings, building expressions, etc.
--------------------------------------------------------------------------------
function M.split(str, delimiter)
  local result = {}
  for match in (str .. delimiter):gmatch("(.-)" .. delimiter) do
    table.insert(result, match)
  end
  return result
end

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
  -- Trim whitespace
  for i, expr in ipairs(exprList) do
    exprList[i] = expr:gsub("^%s+", ""):gsub("%s+$", "")
  end
  return exprList
end

function M.split_by_comma(str)
  local result = {}
  for part in string.gmatch(str, "([^,]+)") do
    table.insert(result, part)
  end
  return result
end

function M.build_multi_expr(exprList)
  if #exprList == 1 then
    return exprList[1]
  else
    return "{" .. table.concat(exprList, ", ") .. "}"
  end
end

function M.get_plot_filename()
  local timestamp = os.date("%Y%m%d_%H%M%S")
  return "plot_" .. timestamp .. ".pdf"
end

--------------------------------------------------------------------------------
-- extract_main_and_curly, extract_expr_and_range, etc.
--------------------------------------------------------------------------------
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

function M.extract_equation_and_variable(selection)
  local parts = M.split_by_comma(selection)
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

--------------------------------------------------------------------------------
-- bracket_if_needed: only wrap in parentheses if there's a top-level + or -
--------------------------------------------------------------------------------
local function bracket_if_needed(expr)
  -- If there's a top-level '+' or '-', we assume multiple terms => wrap in ()
  if expr:find("[+%-]") then
    return "(" .. expr .. ")"
  else
    return expr
  end
end

--------------------------------------------------------------------------------
-- preprocess_equation: Main LaTeX => Wolfram transformations
-- Extended for partial derivatives, sums (\sum), and imaginary unit support.
--------------------------------------------------------------------------------
function M.preprocess_equation(equation)
  debug_print("Preprocess Equ: Input => " .. equation)

  ------------------------------------------------------------------------------
  -- 1) Convert common LaTeX macros and symbols to Wolfram BEFORE escaping backslashes
  ------------------------------------------------------------------------------
  -- (IMAG UNIT SUPPORT) => e.g. \mathrm{i} or \im => I
  -- Add them here so they become "I" in Wolfram syntax.
  equation = equation
    :gsub("\\sin", "Sin")
    :gsub("\\cos", "Cos")
    :gsub("\\tan", "Tan")
    :gsub("\\exp", "Exp")
    :gsub("\\ln",  "Log")
    :gsub("\\log", "LogBase10")
    :gsub("\\pi", "Pi")
    :gsub("\\alpha", "Alpha")
    :gsub("\\tau", "Tau")
    :gsub("\\beta", "Beta")
    :gsub("\\to", "->")
    :gsub("\\infty", "Infinity")
    :gsub("\\left", "")
    :gsub("\\right", "")
    :gsub("\\sqrt", "Sqrt")
    :gsub("\\cdot", "*")
    :gsub("\\mathrm%{i%}", "I")  -- e.g. \mathrm{i} => I
    :gsub("\\im", "I")          -- e.g. \im => I

  equation = equation:gsub("LogBase10%^([0-9]+)%(([^()]+)%)", "LogBase10(%2)^%1")

  debug_print("After basic replacements => " .. equation)

  ------------------------------------------------------------------------------
  -- 1.5) Helper: bracket_if_needed (for fraction code below)
  ------------------------------------------------------------------------------
  local function bracket_if_needed(expr)
    if expr:find("[+%-]") then
      return "(" .. expr .. ")"
    else
      return expr
    end
  end

  ------------------------------------------------------------------------------
  -- 2) Ordinary Derivative Replacement
  --     (Same logic as before for \frac{\mathrm{d}}{\mathrm{d}x} etc.)
  ------------------------------------------------------------------------------
  equation = equation:gsub("\\frac%{\\mathrm%{d%}%}%{\\mathrm%{d%}([a-zA-Z])%}%s*%((%b{})%)", function(var, expr)
    expr = expr:sub(2, -2)
    debug_print("Replacing derivative: var = " .. var .. ", expr = " .. expr)
    return "D[" .. expr .. ", " .. var .. "]"
  end)
  debug_print("After derivative replacement => " .. equation)

  equation = equation:gsub("\\frac%{\\mathrm%{d%}%}%{dx%}%s*%((%b{})%)", function(expr)
    expr = expr:sub(2, -2)
    debug_print("Replacing derivative (short form): expr = " .. expr)
    return "D[" .. expr .. ", x]"
  end)

  equation = equation:gsub(
    "\\frac%{\\mathrm%{d%}%}%{\\mathrm%{d%}([a-zA-Z])%}%s*([^%(][^=]+)",
    function(var, expr)
      expr = expr:match("^%s*(.-)%s*$") or expr
      return "D[" .. expr .. ", " .. var .. "]"
    end
  )
  debug_print("After additional derivative replacement => " .. equation)

  ------------------------------------------------------------------------------
  -- 3) Partial Derivatives
  ------------------------------------------------------------------------------
  local function build_nested_D(expr, vars)
    -- e.g. if vars={"x","y"}, produce D[D[expr, x], y]
    local code = expr
    for _, v in ipairs(vars) do
      code = string.format("D[%s, %s]", code, v)
    end
    return code
  end

  local function parse_partial_vars(varblock)
    -- remove "\partial"
    varblock = varblock:gsub("\\partial", "")
    local vars = {}
    -- e.g. "x^2 y" => token-by-token
    for token in varblock:gmatch("([%a%d%^]+)") do
      local base, exponent = token:match("([a-zA-Z])%^([0-9]+)")
      if base and exponent then
        local n = tonumber(exponent)
        for _=1,n do
          table.insert(vars, base)
        end
      else
        table.insert(vars, token)
      end
    end
    return vars
  end

  -- pattern: \frac{\partial^n}{\partial x^n} ( expr )
  equation = equation:gsub(
    "\\frac%{%\\partial%^(%d+)%}%{%\\partial%s*(.-)%}%s*%((%b{})%)",
    function(order, varblock, expr_paren)
      local expr = expr_paren:sub(2, -2)
      local vars = parse_partial_vars(varblock)
      return build_nested_D(expr, vars)
    end
  )

  -- no parentheses
  equation = equation:gsub(
    "\\frac%{%\\partial%^(%d+)%}%{%\\partial%s*(.-)%}%s*([^%(][^=]+)",
    function(order, varblock, expr)
      expr = expr:match("^%s*(.-)%s*$") or expr
      local vars = parse_partial_vars(varblock)
      return build_nested_D(expr, vars)
    end
  )

  -- single-order partial with parentheses
  equation = equation:gsub(
    "\\frac%{%\\partial%}%{%\\partial%s*([a-zA-Z].-)%}%s*%((%b{})%)",
    function(varblock, expr_paren)
      local expr = expr_paren:sub(2, -2)
      local vars = parse_partial_vars(varblock)
      return build_nested_D(expr, vars)
    end
  )

  -- single-order partial, no parentheses
  equation = equation:gsub(
    "\\frac%{%\\partial%}%{%\\partial%s*([a-zA-Z].-)%}%s*([^%(][^=]+)",
    function(varblock, expr)
      expr = expr:match("^%s*(.-)%s*$") or expr
      local vars = parse_partial_vars(varblock)
      return build_nested_D(expr, vars)
    end
  )

  debug_print("After partial derivatives => " .. equation)


  ------------------------------------------------------------------------------
  -- 3.5) SUM REPLACEMENT: \sum_{i=0}^{\infty} expression => Sum[ expression, {i, 0, Infinity}]
  ------------------------------------------------------------------------------
  -- We'll handle two forms:
  --   \sum_{i=0}^{n} (expr)
  --   \sum_{i=0}^{n} expr   (no parentheses)
  -- We interpret "n" as e.g. "n", "\infty", "2k", etc. 
  -- We'll do a simple pattern for capturing lower, upper.
  ------------------------------------------------------------------------------

  -- Summation with parentheses
  equation = equation:gsub(
    "\\sum_%{([^=]+)=([^}]+)%}%^{([^}]+)}%s*%((%b{})%)",
    function(var, lower, upper, expr_paren)
      local expr = expr_paren:sub(2, -2)  -- remove (...)
      local up = upper:gsub("\\infty", "Infinity")  -- ensure Infinity if used
      return string.format("Sum[%s, {%s, %s, %s}]", expr, var, lower, up)
    end
  )

  -- Summation no parentheses around expression
  equation = equation:gsub(
    "\\sum_%{([^=]+)=([^}]+)%}%^{([^}]+)}%s*([^%(][^=]+)",
    function(var, lower, upper, expr)
      expr = expr:match("^%s*(.-)%s*$") or expr
      local up = upper:gsub("\\infty", "Infinity")
      return string.format("Sum[%s, {%s, %s, %s}]", expr, var, lower, up)
    end
  )

  debug_print("After sums => " .. equation)


  ------------------------------------------------------------------------------
  -- 4) Integrals Replacement: \int_{a}^{b} => Integrate[..., {x, a, b}]
  ------------------------------------------------------------------------------
  equation = equation:gsub("\\int_%{([^}]+)%}%^{([^}]+)%}%s*(.-)%s*\\mathrm%{d%}([a-zA-Z])",
    function(lower, upper, integrand, var)
      return string.format("Integrate[%s, {%s, %s, %s}]", integrand, var, lower, upper)
    end
  )
  equation = equation:gsub("\\int_%{([^}]+)%}%^{([^}]+)%}%s*(.-)%s*d([a-zA-Z])",
    function(lower, upper, integrand, var)
      return string.format("Integrate[%s, {%s, %s, %s}]", integrand, var, lower, upper)
    end
  )

  ------------------------------------------------------------------------------
  -- 5) Replace \mathrm{d}x => dx
  ------------------------------------------------------------------------------
  equation = equation:gsub("\\mathrm%{d%}([a-zA-Z])", "d%1")
  debug_print("After replacing '\\mathrm{d}x' => 'dx' => " .. equation)


  ------------------------------------------------------------------------------
  -- 6) Convert simple and nested fractions: \frac{a}{b} => (a/b)
  ------------------------------------------------------------------------------
  local function replace_fractions(eq)
    while true do
      local prev_eq = eq
      eq = eq:gsub("\\frac%s*(%b{})%s*(%b{})", function(num_brace, den_brace)
        local numerator   = num_brace:sub(2, -2)
        local denominator = den_brace:sub(2, -2)
        debug_print("Matched \\frac: numerator = " .. numerator ..
                    ", denominator = " .. denominator)
        local N = bracket_if_needed(numerator)
        local D = bracket_if_needed(denominator)
        return "(" .. N .. "/" .. D .. ")"
      end)

      if eq == prev_eq then
        break
      end
    end
    return eq
  end

  equation = replace_fractions(equation)
  debug_print("After fraction replacement => " .. equation)


  ------------------------------------------------------------------------------
  -- 7) Replace 'e^{' with 'E^{'
  ------------------------------------------------------------------------------
  equation = equation:gsub("e%^{", "E^{")
  debug_print("After replacing 'e^{' with 'E^{' => " .. equation)


  ------------------------------------------------------------------------------
  -- 8) Handle function calls, etc. (LogBase10 => Log[10,...], etc.)
  ------------------------------------------------------------------------------
  equation = equation:gsub("([A-Za-z]+)%^([0-9]+)%(([^()]+)%)", "%1(%3)^%2")

  equation = equation:gsub("%(%(", "(")
  equation = equation:gsub("%)%)", ")")

  equation = equation:gsub("([A-Za-z]+)%(([^()]+)%)", "%1[%2]")
  equation = equation:gsub("([A-Za-z]+)%(([^()]+)%)", "%1[%2]")

  equation = equation:gsub("([%w_]+)%s*%(%s*(.-)%s*%)", "%1[%2]")
  equation = equation:gsub("([%w_]+)%s*%(%s*(.-)%s*%)", "%1[%2]")

  equation = equation:gsub("LogBase10%[([^%]]+)%]", "Log[10, %1]")

  debug_print("After function call replacement => " .. equation)


  ------------------------------------------------------------------------------
  -- 9) Remove LaTeX spacing macros like \, \: \; \!
  ------------------------------------------------------------------------------
  equation = equation:gsub("\\[%s:,;!]", "")
  debug_print("After removing spacing macros => " .. equation)


  ------------------------------------------------------------------------------
  -- 10) Limit Replacement
  ------------------------------------------------------------------------------
  equation = equation:gsub("\\lim%s*_%s*%{([^}]+)%}%s*([^%^]+)%^([%w]+)", function(limit, expr, power)
    local var, a = limit:match("([%w]+)%s*->%s*(.+)")
    if var and a then
      expr = expr:gsub("^%s*%((.*)%)%s*$", "%1")
      local expr_with_power = "(" .. expr .. ")^" .. power
      debug_print(string.format("Replacing limit with exponent: Limit[%s, %s -> %s]", expr_with_power, var, a))
      return string.format("Limit[%s, %s -> %s]", expr_with_power, var, a)
    else
      debug_print("Error: Invalid \\lim syntax. Expected format: \\lim_{var \\to a} (expr)^power")
      return "\\lim{" .. limit .. "}(" .. expr .. ")^" .. power
    end
  end)
  debug_print("After Limit replacement (12a) => " .. equation)

  equation = equation:gsub("\\lim%s*_%s*%{([^}]+)%}%s*%{([^}]+)%}", function(limit, expr)
    local var, a = limit:match("([%w]+)%s*->%s*(.+)")
    if var and a then
      debug_print(string.format("Replacing limit: Limit[%s, %s -> %s]", expr, var, a))
      return string.format("Limit[%s, %s -> %s]", expr, var, a)
    else
      debug_print("Error: Invalid \\lim syntax. Expected format: \\lim_{var \\to a}{expr}")
      return "\\lim{" .. limit .. "}{" .. expr .. "}"
    end
  end)
  debug_print("After Limit replacement (12b) => " .. equation)

  equation = equation:gsub("\\lim%s*_%s*%{([^}]+)%}%s*%(([^)]+)%)", function(limit, expr)
    local var, a = limit:match("([%w]+)%s*->%s*(.+)")
    if var and a then
      debug_print(string.format("Replacing limit: Limit[%s, %s -> %s]", expr, var, a))
      return string.format("Limit[%s, %s -> %s]", expr, var, a)
    else
      debug_print("Error: Invalid \\lim syntax. Expected format: \\lim_{var \\to a} (expr)")
      return "\\lim{" .. limit .. "}(" .. expr .. ")"
    end
  end)
  debug_print("After Limit replacement (12c) => " .. equation)


  ------------------------------------------------------------------------------
  -- 11) Escape backslashes and double quotes for shell usage
  ------------------------------------------------------------------------------
  equation = equation:gsub("\\", "\\\\")
  equation = equation:gsub('"', '\\"')
  debug_print("After escaping backslashes and quotes => " .. equation)

  debug_print("Final preprocessed equation => " .. equation)
  return equation
end




-- Simple validation to check for balanced brackets
function M.is_balanced(str)
  local stack = {}
  local pairs = { ["("] = ")", ["{"] = "}", ["["] = "]" }
  for i = 1, #str do
    local c = str:sub(i,i)
    if pairs[c] then
      table.insert(stack, pairs[c])
    elseif c == ")" or c == "}" or c == "]" then
      local expected = table.remove(stack)
      if c ~= expected then
        return false
      end
    end
  end
  return #stack == 0
end

-- Extract unique variables from a list of equations
function M.extract_variables(equations)
  local vars = {}
  -- List of known Wolfram functions to exclude from variables
  local knownFunctions = {
    ["Sin"] = true, ["Cos"] = true, ["Tan"] = true, ["Exp"] = true,
    ["Log"] = true, ["Pi"] = true, ["Alpha"] = true, ["Tau"] = true,
    ["Beta"] = true, ["D"] = true, ["Integrate"] = true, ["Plot"] = true,
    ["Solve"] = true, ["FullSimplify"] = true, ["Sqrt"] = true, ["NSolve"] = true  -- Added "NSolve"
  }

  for _, eq in ipairs(equations) do
    for var in eq:gmatch("[A-Za-z]+") do
      -- Exclude known function names (case-sensitive)
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
