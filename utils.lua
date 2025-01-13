--------------------------------------------------------------------------------
-- utils.lua
-- Utility functions used across the plugin.
--------------------------------------------------------------------------------

-- 1) Setup
--------------------------------------------------------------------------------
local M = {}

-- a) Debug printing
--------------------------------------------------------------------------------
local DEBUG = true                -- Set DEBUG to true to print Debug-messages
local function debug_print(msg)
  if DEBUG then
    print("DEBUG: " .. msg)       -- If DEBUG is true then print the debug messages
  end
end

M.debug_print = debug_print


-- b) Parsing results
--------------------------------------------------------------------------------
function M.parse_result(raw_result)
  if not raw_result then                                        -- If no raw_result is passed to the function, then
    return ""                                                   -- Return an empty string
  end
  raw_result = raw_result:gsub("[%z\1-\31]", "")                -- Remove non-printable characters
  raw_result = raw_result:match("^%s*(.-)%s*$") or raw_result   -- Trim whitespace
  return raw_result                                             -- Return a parsed result
end


-- c) Helper-function for Preprocess_equation that adds brackets
--------------------------------------------------------------------------------
local function bracket_if_needed(expr)
  if expr:find("[+%-]") then    -- If the expression contains either +, % or -, then
    return "(" .. expr .. ")"   -- Bracket the expression
  else
    return expr
  end
end




-- 2) Helpers for splitting strings, building expressions, etc.
--------------------------------------------------------------------------------

-- a) Function that splits str into a table of substrings based on the specified delimiter
--------------------------------------------------------------------------------
function M.split(str, delimiter)
  local result = {}
  for match in (str .. delimiter):gmatch("(.-)" .. delimiter) do 
    table.insert(result, match)
  end
  return result
end


-- b) Function that splits multiple mathematical expressions seperated by commas into seperate expressions
--------------------------------------------------------------------------------
function M.split_expressions(exprPart)
  local exprList = {}     -- Table to store individual expressions
  local current = ""      -- Accumulates characters for the current expression
  local depth = 0         -- Tracks the nesting depth based on parenthesis, brackets and braces
  for i = 1, #exprPart do                         -- Iterate over each character in exprPart
    local c = exprPart:sub(i, i)                  -- Retrieves the current character
    if c == "[" or c == "{" or c == "(" then      -- If the current character is an openening parenthesis, backet or brace, then
      depth = depth + 1                           -- Increase the depth
    elseif c == "]" or c == "}" or c == ")" then  -- If the current character is a closing parenthesis, bracket or brace, then
      depth = depth - 1                           -- Decrease the depth
    elseif c == "," and depth == 0 then           -- Elseif the current character is a , and the depth is 0 then
      table.insert(exprList, current)             -- Insert current into the exprList
      current = ""                                -- Reset current
      goto continue                               -- Skips the comma
    end
    current = current .. c            -- Add current character to current
    ::continue::
  end
  if current ~= "" then               -- If there is remaining content in current, then
    table.insert(exprList, current)   -- Add it to the exprList
  end

  for i, expr in ipairs(exprList) do  -- Loop over all expressions
    exprList[i] = expr:gsub("^%s+", ""):gsub("%s+$", "")  -- Trim whitespace
  end
  return exprList   -- Return the processed list of equations
end


-- c) Fucntion that splits a string by commas without considering nested structure or depth
--------------------------------------------------------------------------------
function M.split_by_comma(str)
  local result = {}
  for part in string.gmatch(str, "([^,]+)") do  -- Captures sequences that are not commas
    table.insert(result, part)                  -- Appends them to the results
  end
  return result
end


-- d) Constructs a single expression string from a list of multiple expressions
--------------------------------------------------------------------------------
function M.build_multi_expr(exprList)
  if #exprList == 1 then  -- If only one expression is passed to the function, then
    return exprList[1]    -- Return that function
  else
    return "{" .. table.concat(exprList, ", ") .. "}"   -- Else concatenate all expressions in exprList with commas and enclose them all in {...}
  end
end


-- e) Function that finds a filename for plots
--------------------------------------------------------------------------------
function M.get_plot_filename()
  local timestamp = os.date("%Y%m%d_%H%M%S")  -- Save the current time as a timestamp
  return "plot_" .. timestamp .. ".pdf"       -- name the plot as "plot_TIMESTAMP.pdf"
end




-- 3) Extraction-functions
--------------------------------------------------------------------------------

-- a) Function that extracts style-specs
--------------------------------------------------------------------------------
function M.extract_main_and_curly(selection)
  local last_mainExpr = selection   -- Defaults last_mainExpr to the entire selection
  local last_curlySpec = nil        -- Defaults the last_curlySpec (style-spec) to nil
  local balance = 0                 -- Tracks the nesting level of braces
  local last_open = 0               -- Stores the postion of the last opened curly-brace at depth 1

  for i = 1, #selection do          -- Loop through each character in selection
    local c = selection:sub(i, i)   -- Retrieve the current character
    if c == "{" then                -- If c is {, then
      balance = balance + 1         -- Increment the balance counter
      if balance == 1 then          -- If the nesting-level is now 1, then
        last_open = i               -- Store the position of the last {
      end
    elseif c == "}" then                                                          -- If c is }, then
      balance = balance - 1                                                       -- Subtract one from the balance counter
      if balance == 0 and last_open > 0 then                                      -- If a balanced pair of {} has been found, then
        local mainExpr = selection:sub(1, last_open -1):match("^%s*(.-)%s*$")     -- Store the mainExpr as everything until {
        local curlySpec = selection:sub(last_open +1, i -1):match("^%s*(.-)%s*$") -- and stor curlySpec as everything within {}
        last_mainExpr = mainExpr                                                  -- Set last_mainExpr to the current mainExpr
        last_curlySpec = curlySpec                                                -- Set last_curlySpec to the current curlySpec
      end
    end
  end

  return last_mainExpr, last_curlySpec  -- Returns the main-expression and the style-spec
end


-- b) Function that extracts range-specs
--------------------------------------------------------------------------------
function M.extract_expr_and_range(mainExpr)
  mainExpr = mainExpr:match("^%s*(.-)%s*$")   -- Trim whitespace

  local last_open = mainExpr:match(".*()%[")  -- Sets the last [ as last_open
  local last_close = mainExpr:match("()%]")   -- Sets the last ] as last_close

  if last_open and last_close and last_close > last_open then                             -- If last_open and last_close makes sense, then
    local exprPart = mainExpr:sub(1, last_open - 1):match("^%s*(.-)%s*$")                 -- Set the exprPart to be everything until [
    local rangeSpec = mainExpr:sub(last_open + 1, last_close - 1):match("^%s*(.-)%s*$")   -- Set the rangeSpec to be everything within []
    return exprPart, rangeSpec                                                            -- Return the expression and the rangeSpec
  else
    return mainExpr, nil  -- If no rangeSpec is found just return the mainExpr
  end
end


-- c) Function that extracts equation and variable
--------------------------------------------------------------------------------
function M.extract_equation_and_variable(selection)
  local parts = M.split_by_comma(selection)   -- Splits the selection at commas using split_by_comma
  if #parts < 2 then                          -- If there are less than two "parts", then
    return nil, nil, "Input must be in the format: equation, variable"  -- Return an error
  end
  local equation = parts[1]:match("^%s*(.-)%s*$")   -- Equation is set to be everything in the first part
  local variable = parts[2]:match("^%s*(.-)%s*$")   -- Variable is set to be everything in the last part
  if not equation or not variable or variable == "" then    -- If there is no equation, no variable or the variable is an empty string, then
    return nil, nil, "Failed to parse equation and variable. Ensure format: equation, variable"   -- Return an error
  end
  if not equation:find(variable) then               -- If the variable is not in the expression, then
    return nil, nil, "Variable '" .. variable .. "' not found in the equation."   -- Return an error
  end
  return equation, variable, nil  -- Return the equation and the variable
end



-- 4) preprocess_equation from LaTeX => Wolfram
--------------------------------------------------------------------------------
function M.preprocess_equation(equation)
  debug_print("Preprocess Equ: Input => " .. equation)  -- (Optionally) prints the equation to be preprocessed


  -- a) Convert common LaTeX macros and symbols to Wolfram BEFORE escaping backslashes
  ------------------------------------------------------------------------------
  equation = equation             -- Define common macros
    :gsub("\\sin", "Sin")
    :gsub("\\cos", "Cos")
    :gsub("\\tan", "Tan")
    :gsub("\\exp", "Exp")
    :gsub("\\ln",  "Log")
    :gsub("\\log", "LogBase10")   -- Placeholder value so \log is log_10 and \ln is log_e
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
    :gsub("\\mathrm%{i%}", "I")
    :gsub("\\im", "I")

  equation = equation:gsub("LogBase10%^([0-9]+)%(([^()]+)%)", "LogBase10(%2)^%1")   -- Handle \log^2 and the likes

  debug_print("After basic replacements => " .. equation)   -- (Optionally) print the equation after replacements of macros


  -- b) Ordinary Derivative Replacement
  ------------------------------------------------------------------------------
  -- Captures \frac{\mathrm{d}}{\mathrm{d}var} expr
  equation = equation:gsub("\\frac%{\\mathrm%{d%}%}%{\\mathrm%{d%}([a-zA-Z])%}%s*%((%b{})%)", function(var, expr)
    expr = expr:sub(2, -2)
    debug_print("Replacing derivative: var = " .. var .. ", expr = " .. expr)   -- (Optionally) print the derivative replacement
    return "D[" .. expr .. ", " .. var .. "]"                                   -- Format the string 
  end)
  debug_print("After derivative replacement => " .. equation)                   -- (Optionally) print the expression after the derivative replacement

  equation = equation:gsub(
    "\\frac%{\\mathrm%{d%}%}%{\\mathrm%{d%}([a-zA-Z])%}%s*([^%(][^=]+)",
    function(var, expr)
      expr = expr:match("^%s*(.-)%s*$") or expr
      return "D[" .. expr .. ", " .. var .. "]"
    end
  )
  debug_print("After additional derivative replacement => " .. equation)


  -- c) Partial Derivatives
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

  -- Matches \frac{\partial^n}{\partial x^n} ( expr )
  equation = equation:gsub(
    "\\frac%{%\\partial%^(%d+)%}%{%\\partial%s*(.-)%}%s*%((%b{})%)",
    function(order, varblock, expr_paren)
      local expr = expr_paren:sub(2, -2)
      local vars = parse_partial_vars(varblock)
      return build_nested_D(expr, vars)
    end
  )

  -- Matches \frac{\partial^n}{\partial x^n} expr
  equation = equation:gsub(
    "\\frac%{%\\partial%^(%d+)%}%{%\\partial%s*(.-)%}%s*([^%(][^=]+)",
    function(order, varblock, expr)
      expr = expr:match("^%s*(.-)%s*$") or expr
      local vars = parse_partial_vars(varblock)
      return build_nested_D(expr, vars)
    end
  )

  -- Matches \frac{\partial}{\partial x} ( expr )
  equation = equation:gsub(
    "\\frac%{%\\partial%}%{%\\partial%s*([a-zA-Z].-)%}%s*%((%b{})%)",
    function(varblock, expr_paren)
      local expr = expr_paren:sub(2, -2)
      local vars = parse_partial_vars(varblock)
      return build_nested_D(expr, vars)
    end
  )

  -- Matches \frac{\partial}{\partial x} expr
  equation = equation:gsub(
    "\\frac%{%\\partial%}%{%\\partial%s*([a-zA-Z].-)%}%s*([^%(][^=]+)",
    function(varblock, expr)
      expr = expr:match("^%s*(.-)%s*$") or expr
      local vars = parse_partial_vars(varblock)
      return build_nested_D(expr, vars)
    end
  )

  debug_print("After partial derivatives => " .. equation)  -- (Optionally) print the equation after patial derivatives have been replaced


  -- d) Sum handling: \sum_{i=0}^{\infty} expression => Sum[ expression, {i, 0, Infinity}]
------------------------------------------------------------------------------
  -- Summation with parentheses
  equation = equation:gsub(
    "\\sum_%{([^=]+)=([^}]+)%}%^{([^}]+)}%s*%((%b{})%)",    -- Matches \sum_{var = lower)^{upper} ( expr_paren )
    function(var, lower, upper, expr_paren)
      local expr = expr_paren:sub(2, -2)                    -- remove (...)
      local up = upper:gsub("\\infty", "Infinity")          -- ensure Infinity if used
      return string.format("Sum[%s, {%s, %s, %s}]", expr, var, lower, up)
    end
  )

  -- Summation no parentheses around expression
  equation = equation:gsub(
    "\\sum_%{([^=]+)=([^}]+)%}%^{([^}]+)}%s*([^%(][^=]+)",  -- Matches \sum_{var = lower}^{upper} expr
    function(var, lower, upper, expr)
      expr = expr:match("^%s*(.-)%s*$") or expr
      local up = upper:gsub("\\infty", "Infinity")
      return string.format("Sum[%s, {%s, %s, %s}]", expr, var, lower, up)
    end
  )

  debug_print("After sums => " .. equation)                 -- (Optionally) print the equation after sums have been replaced


  -- e) Integrals Replacement: \int_{a}^{b} => Integrate[..., {x, a, b}]
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


  -- f) Replace \mathrm{d}x => dx
  ------------------------------------------------------------------------------
  equation = equation:gsub("\\mathrm%{d%}([a-zA-Z])", "d%1")
  debug_print("After replacing '\\mathrm{d}x' => 'dx' => " .. equation)


  -- g) Convert simple and nested fractions: \frac{a}{b} => (a/b)
  ------------------------------------------------------------------------------
  local function replace_fractions(eq)
    while true do         -- Continues until told to break
      local prev_eq = eq  -- set prev_eq equal to eq
      eq = eq:gsub("\\frac%s*(%b{})%s*(%b{})", function(num_brace, den_brace)   -- num_brace matches the numerator and den_brace the denominator in \frac{}{}
        local numerator   = num_brace:sub(2, -2)                                -- Removes the outer brace from the numerator
        local denominator = den_brace:sub(2, -2)                                -- Removes the outer brace from the denominator
        debug_print("Matched \\frac: numerator = " .. numerator ..              -- (Optionally) print the matched numerator and denominator
                    ", denominator = " .. denominator)
        local N = bracket_if_needed(numerator)                                  -- Wraps the numerator in parenthesis if conatining either +, - or %
        local D = bracket_if_needed(denominator)                                -- Wraps the denominator in parenthesis if containing either +, - or %
        return "(" .. N .. "/" .. D .. ")"                                      -- Return a string formatted as ( numerator / denominator)
      end)

      if eq == prev_eq then   -- If no change occured break the loop
        break
      end
    end
    return eq                 -- Return the reformatted equation
  end

  equation = replace_fractions(equation)  -- Call the function
  debug_print("After fraction replacement => " .. equation)   -- (Optionally) print the equation after fractions have been replaced


  -- h) Replace 'e^{' with 'E^{'
  ------------------------------------------------------------------------------
  equation = equation:gsub("e%^{", "E^{")   -- Matches e^{ and replaces with E^{
  debug_print("After replacing 'e^{' with 'E^{' => " .. equation)   -- (Optionally) print the equation after e^{ have been replaced with E^{


  -- i) Handle function calls, etc. (LogBase10 => Log[10,...], etc.)
  ------------------------------------------------------------------------------
  equation = equation:gsub("([A-Za-z]+)%^([0-9]+)%(([^()]+)%)", "%1(%3)^%2")  -- Captures function-name, exponent and argument from e.g. \sin^2(2x) and formats it as sin(2x)^2

  equation = equation:gsub("%(%(", "(")                                       -- Collapses (( into (
  equation = equation:gsub("%)%)", ")")                                       -- Collapses )) into )

  equation = equation:gsub("([A-Za-z]+)%(([^()]+)%)", "%1[%2]")               -- Converts function calls from func(arg) to func[arg]
  equation = equation:gsub("([A-Za-z]+)%(([^()]+)%)", "%1[%2]")               -- Duplicate to handle nested functions

  equation = equation:gsub("([%w_]+)%s*%(%s*(.-)%s*%)", "%1[%2]")             -- Converts function calls from func_2(arg) to func_2[arg]
  equation = equation:gsub("([%w_]+)%s*%(%s*(.-)%s*%)", "%1[%2]")             -- Duplicate to handle nested funtions

  equation = equation:gsub("LogBase10%[([^%]]+)%]", "Log[10, %1]")            -- Matches placeholder LogBase10[arg] ang formats it as Log[10, %1]

  debug_print("After function call replacement => " .. equation)              -- (Optionally) print the equation after function call replacement


  -- j) Remove LaTeX spacing macros like \, \: \; \!
  ------------------------------------------------------------------------------
  equation = equation:gsub("\\[%s:,;!]", "")                    -- Matches spacing macros like \, \: \; and \!
  debug_print("After removing spacing macros => " .. equation)  --(Optionally) print the equation after removing spacing macros


  -- k) Limit Replacement
  ------------------------------------------------------------------------------
  equation = equation:gsub("\\lim%s*_%s*%{([^}]+)%}%s*([^%^]+)%^([%w]+)",                                       -- Matches \lim_{ limit } ( expr )^(power) and substitutes with function below
  function(limit, expr, power)
    local var, a = limit:match("([%w]+)%s*->%s*(.+)")                                                           -- Searches limit and matches var with the variable and a with the point of approach
    if var and a then                                                                                           -- If the variable and point of approach are extracted as expected, then
      expr = expr:gsub("^%s*%((.*)%)%s*$", "%1")                                                                -- Removes surrounding parenthesis from expr
      local expr_with_power = "(" .. expr .. ")^" .. power                                                      -- Wraps expression in (...)^power
      debug_print(string.format("Replacing limit with exponent: Limit[%s, %s -> %s]", expr_with_power, var, a)) -- (Optionally) print information about how the limit has been handled
      return string.format("Limit[%s, %s -> %s]", expr_with_power, var, a)
    else
      debug_print("Error: Invalid \\lim syntax. Expected format: \\lim_{var \\to a} (expr)^power")              -- If either var or a is not extracted properly then return an error
      return "\\lim{" .. limit .. "}(" .. expr .. ")^" .. power
    end
  end)
  debug_print("After Limit replacement (12a) => " .. equation)                                                  -- (Optionally) print the equation after replacing limits with exponents

  equation = equation:gsub("\\lim%s*_%s*%{([^}]+)%}%s*%{([^}]+)%}", function(limit, expr)                       -- Matches \lim_{ limit } { expr } and substitutes with function below
    local var, a = limit:match("([%w]+)%s*->%s*(.+)")                                                           -- Searches limit and matches var with the variable and a with the point of approach
    if var and a then                                                                                           -- If the variable and point of approach are extracted as expected, then
      debug_print(string.format("Replacing limit: Limit[%s, %s -> %s]", expr, var, a))                          -- (Optionally) print information about how the limit has been handled
      return string.format("Limit[%s, %s -> %s]", expr, var, a)
    else
      debug_print("Error: Invalid \\lim syntax. Expected format: \\lim_{var \\to a}{expr}")                     -- If either var or a is not extracted properly then return an error
      return "\\lim{" .. limit .. "}{" .. expr .. "}"
    end
  end)
  debug_print("After Limit replacement (12b) => " .. equation)                                                  -- (Optionally) print the equation after replacing {}-limits

  equation = equation:gsub("\\lim%s*_%s*%{([^}]+)%}%s*%(([^)]+)%)", function(limit, expr)                       -- Matches \lim_{ limit } (expr) and substitutes with function below
    local var, a = limit:match("([%w]+)%s*->%s*(.+)")                                                           -- Searches limit ant matches var with the variable and a with the point of approach
    if var and a then                                                                                           -- If the variable and point of approach are extracted as expected, then
      debug_print(string.format("Replacing limit: Limit[%s, %s -> %s]", expr, var, a))                          -- (Optionally) print information about how the limit has been handled
      return string.format("Limit[%s, %s -> %s]", expr, var, a)
    else
      debug_print("Error: Invalid \\lim syntax. Expected format: \\lim_{var \\to a} (expr)")                    -- If either var or a is not extracted properly then return an error
      return "\\lim{" .. limit .. "}(" .. expr .. ")"
    end
  end)
  debug_print("After Limit replacement (12c) => " .. equation)                                                  -- (Optionally) print the equation after replacing ()-limits


  -- l) Escape backslashes and double quotes for shell usage
  ------------------------------------------------------------------------------
  equation = equation:gsub("\\", "\\\\")                                  -- Escape backslashes
  equation = equation:gsub('"', '\\"')                                    -- Escape double-quotes
  debug_print("After escaping backslashes and quotes => " .. equation)    -- (Optionally) print the equation after escaping backslashes and quotes

  debug_print("Final preprocessed equation => " .. equation)              -- (Optinoally) print the final preprocessed equation
  return equation
end




-- 5) Validation-function that checks for balanced brackets
--------------------------------------------------------------------------------
function M.is_balanced(str)
  local stack = {}
  local pairs = { ["("] = ")", ["{"] = "}", ["["] = "]" }   -- Maps each opening bracket to the corresponding closing bracket
  for i = 1, #str do                                        -- Loop through all the characters in the string
    local c = str:sub(i,i)                                  -- Retrieve the current character
    if pairs[c] then                                        -- If the current character is an opening bracket, then
      table.insert(stack, pairs[c])                         -- Push the corresponding closing bracket into the stack
    elseif c == ")" or c == "}" or c == "]" then            -- If c is a closing bracket, then
      local expected = table.remove(stack)                  -- pop the last expected closing bracket from the stack
      if c ~= expected then                                 -- If the popped bracket does not match c then
        return false                                        -- return false
      end
    end
  end
  return #stack == 0                                        -- If the stack is empty after the loop then the check passed
end




-- 6 Fundtion that extracts unique variables from a list of equations
--------------------------------------------------------------------------------
function M.extract_variables(equations)
  local vars = {}
  local knownFunctions = {    -- Define known WolframFunctions and other content to explude from variable searches
    ["Sin"] = true, ["Cos"] = true, ["Tan"] = true, ["Exp"] = true,
    ["Log"] = true, ["Pi"] = true, ["Alpha"] = true, ["Tau"] = true,
    ["Beta"] = true, ["D"] = true, ["Integrate"] = true, ["Plot"] = true,
    ["Solve"] = true, ["FullSimplify"] = true, ["Sqrt"] = true, ["NSolve"] = true
  }

  for _, eq in ipairs(equations) do       -- Iterates over each equation
    for var in eq:gmatch("[A-Za-z]+") do  -- Extracts sequences of aphabetical characters (function and variable names)
      if not knownFunctions[var] then     -- If the extracted var is not a part of knownFunctions, then
        vars[var] = true                  -- Add the variable to vars
      end
    end
  end
  local varList = {}
  for var, _ in pairs(vars) do            -- For all the keys in vars
    table.insert(varList, var)            -- Insert the key into varList
  end
  return varList                          -- Return varList
end

return M
