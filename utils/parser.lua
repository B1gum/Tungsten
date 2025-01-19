--------------------------------------------------------------------------------
-- parser.lua
-- Main LaTeX-WolframScript parsing-module.
--------------------------------------------------------------------------------

local io_utils = require("tungsten.utils.io_utils").debug_print
local M = {}


-- a) Convert common LaTeX macros and symbols to Wolfram BEFORE escaping backslashes
local function basic_replacements(eq)
  eq = eq
    :gsub("\\sin", "Sin")
    :gsub("\\cos", "Cos")
    :gsub("\\tan", "Tan")
    :gsub("\\exp", "Exp")
    :gsub("\\ln",  "Log")
    :gsub("\\log", "Log10")
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
    :gsub("e%^", "E^")
    :gsub("\\[%s:,;!]", "")
    :gsub("\\mathrm%{d%}([a-zA-Z])", "d%1")

  eq = eq:gsub("Log10%^([0-9]+)%(([^()]+)%)", "Log10(%2)^%1")

  return eq
end


-- b) Ordinary Derivative Replacement
local function ordinary_derivative(eq)
  eq = eq:gsub("\\frac%{\\mathrm%{d%}%}%{\\mathrm%{d%}([a-zA-Z])%}%s*%((%b{})%)", function(var, expr)
    expr = expr:sub(2, -2)
    io_utils("Replacing derivative: var = " .. var .. ", expr = " .. expr)
    return "D[" .. expr .. ", " .. var .. "]"
  end)

  eq = eq:gsub(
    "\\frac%{\\mathrm%{d%}%}%{\\mathrm%{d%}([a-zA-Z])%}%s*([^%(][^=]+)",
    function(var, expr)
      expr = expr:match("^%s*(.-)%s*$") or expr
      return "D[" .. expr .. ", " .. var .. "]"
    end
  )

  return eq
end


-- c) Partial Derivatives
local function partial_derivative(eq)
  local function build_nested_D(expr, vars)
    local code = expr
    for _, v in ipairs(vars) do
      code = string.format("D[%s, %s]", code, v)
    end
    return code
  end

  local function parse_partial_vars(varblock)
    varblock = varblock:gsub("\\partial", "")
    local vars = {}
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

  eq = eq:gsub(
    "\\frac%{%\\partial%^(%d+)%}%{%\\partial%s*(.-)%}%s*%((%b{})%)",
    function(order, varblock, expr_paren)
      local expr = expr_paren:sub(2, -2)
      local vars = parse_partial_vars(varblock)
      return build_nested_D(expr, vars)
    end
  )

  eq = eq:gsub(
    "\\frac%{%\\partial%^(%d+)%}%{%\\partial%s*(.-)%}%s*([^%(][^=]+)",
    function(order, varblock, expr)
      expr = expr:match("^%s*(.-)%s*$") or expr
      local vars = parse_partial_vars(varblock)
      return build_nested_D(expr, vars)
    end
  )

  eq = eq:gsub(
    "\\frac%{%\\partial%}%{%\\partial%s*([a-zA-Z].-)%}%s*%((%b{})%)",
    function(varblock, expr_paren)
      local expr = expr_paren:sub(2, -2)
      local vars = parse_partial_vars(varblock)
      return build_nested_D(expr, vars)
    end
  )

  eq = eq:gsub(
    "\\frac%{%\\partial%}%{%\\partial%s*([a-zA-Z].-)%}%s*([^%(][^=]+)",
    function(varblock, expr)
      expr = expr:match("^%s*(.-)%s*$") or expr
      local vars = parse_partial_vars(varblock)
      return build_nested_D(expr, vars)
    end
  )
  return eq
end


-- d) Sum handling: \sum_{i=0}^{\infty} expression => Sum[ expression, {i, 0, Infinity}]
local function sum(eq)
  eq = eq:gsub(
    "\\sum_%{([^=]+)=([^}]+)%}%^{([^}]+)}%s*%((%b{})%)",
    function(var, lower, upper, expr_paren)
      local expr = expr_paren:sub(2, -2)
      local up = upper:gsub("\\infty", "Infinity")
      return string.format("Sum[%s, {%s, %s, %s}]", expr, var, lower, up)
    end
  )

  eq = eq:gsub(
    "\\sum_%{([^=]+)=([^}]+)%}%^{([^}]+)}%s*([^%(][^=]+)",
    function(var, lower, upper, expr)
      expr = expr:match("^%s*(.-)%s*$") or expr
      local up = upper:gsub("\\infty", "Infinity")
      return string.format("Sum[%s, {%s, %s, %s}]", expr, var, lower, up)
    end
  )
  return eq
end


-- e) Integrals Replacement: \int_{a}^{b} => Integrate[..., {x, a, b}]
local function integral(eq)
  ---------------------------------------------------------------------------
  -- PASS 1: Definite integral WITH braces
  -- Matches: \int_{a}^{b} <EXPR> dx
  -- e.g. "\int_{0}^{1} x^{2} dx"
  ---------------------------------------------------------------------------
  eq = eq:gsub(
    "\\int_%{([^}]+)%}%^%{([^}]+)%}%s*(.-)%s*d([a-zA-Z]+)",
    function(lower, upper, expr, var)
      if expr:match("^%s*$") then
        expr = ""  -- If integrand is empty => "Integrate[], var"
      end
      return string.format("Integrate[%s, {%s, %s, %s}]", expr, var, lower, upper)
    end
  )

  ---------------------------------------------------------------------------
  -- PASS 2: Definite integral WITHOUT braces
  -- Matches: \int_a^b <EXPR> dx
  -- e.g. "\int_0^1 e^z dz"
  ---------------------------------------------------------------------------
  eq = eq:gsub(
    "\\int_([^%s]+)%^([^%s]+)%s*(.-)%s*d([a-zA-Z]+)",
    function(lower, upper, expr, var)
      if expr:match("^%s*$") then
        expr = ""
      end
      return string.format("Integrate[%s, {%s, %s, %s}]", expr, var, lower, upper)
    end
  )

  ---------------------------------------------------------------------------
  -- PASS 3: Indefinite integrals
  -- Matches: \int <EXPR> dx
  -- e.g. "\int e^x dx"
  ---------------------------------------------------------------------------
  eq = eq:gsub(
    "\\int%s*(.-)%s*d([a-zA-Z]+)",
    function(expr, var)
      if expr:match("^%s*$") then
        expr = ""
      end
      return string.format("Integrate[%s, %s]", expr, var)
    end
  )

  return eq
end


-- f) Convert simple and nested fractions: \frac{a}{b} => (a/b)
local function replace_fractions(eq)
  while true do
    local prev_eq = eq
    eq = eq:gsub("\\frac%s*(%b{})%s*(%b{})", function(num_brace, den_brace)
      local numerator   = num_brace:sub(2, -2)
      local denominator = den_brace:sub(2, -2)
      io_utils("Matched \\frac: numerator = " .. numerator .. ", denominator = " .. denominator)
      local N = require("tungsten.utils.string_utils").bracket_if_needed(numerator)
      local D = require("tungsten.utils.string_utils").bracket_if_needed(denominator)
      return "(" .. N .. "/" .. D .. ")"
    end)

    if eq == prev_eq then
      break
    end
  end

  return eq
end


-- g) Handle function calls, etc. (Log10 => Log[10,...], etc.)
local function function_calls(eq)
  eq = eq:gsub("([A-Za-z]+)%^([0-9]+)%(([^()]+)%)", "%1(%3)^%2")
  eq = eq:gsub("([A-Za-z]+)%(([^()]+)%)", "%1[%2]")
  eq = eq:gsub("([A-Za-z]+)%(([^()]+)%)", "%1[%2]")
  eq = eq:gsub("([%w_]+)%s*%(%s*(.-)%s*%)", "%1[%2]")
  eq = eq:gsub("([%w_]+)%s*%(%s*(.-)%s*%)", "%1[%2]")
  eq = eq:gsub("Log10%[([^%]]+)%]", "Log[10, %1]")

  return eq
end


-- h) Handle limits
local function limits(eq)

  ---------------------------------------------------------------------------
  -- PASS 1: \lim_{var -> a} (expr)^power
  -- e.g.  \lim_{x -> 0} (x^2)^3 => Limit[(x^2)^3, x -> 0]
  ---------------------------------------------------------------------------
  eq = eq:gsub(
    "\\lim%s*_%s*%{([^}]+)%}%s*%(([^)]+)%)%^(%w+)",
    function(limit_block, expr, power)
      local var, a = limit_block:match("([%w]+)%s*->%s*(.+)")
      if var and a then
        local expr_with_power = "(" .. expr .. ")^" .. power
        return string.format("Limit[%s, %s -> %s]", expr_with_power, var, a)
      else
        -- If var->a parse failed, leave it as is (or do an error message)
        return "\\lim_{" .. limit_block .. "}(" .. expr .. ")^" .. power
      end
    end
  )

  ---------------------------------------------------------------------------
  -- PASS 2: \lim_{var -> a}{expr}
  -- e.g.  \lim_{z -> 1}{z^2} => Limit[z^2, z -> 1]
  ---------------------------------------------------------------------------
  eq = eq:gsub(
    "\\lim%s*_%s*%{([^}]+)%}%s*%{([^}]+)%}",
    function(limit_block, expr)
      local var, a = limit_block:match("([%w]+)%s*->%s*(.+)")
      if var and a then
        return string.format("Limit[%s, %s -> %s]", expr, var, a)
      else
        return "\\lim_{" .. limit_block .. "}{" .. expr .. "}"
      end
    end
  )

  ---------------------------------------------------------------------------
  -- PASS 3: \lim_{var -> a} (expr) (no exponent)
  -- e.g.  \lim_{y -> Infinity} (1/y)
  ---------------------------------------------------------------------------
  eq = eq:gsub(
    "\\lim%s*_%s*%{([^}]+)%}%s*%(([^)]+)%)",
    function(limit_block, expr)
      local var, a = limit_block:match("([%w]+)%s*->%s*(.+)")
      if var and a then
        return string.format("Limit[%s, %s -> %s]", expr, var, a)
      else
        return "\\lim_{" .. limit_block .. "}(" .. expr .. ")"
      end
    end
  )

  ---------------------------------------------------------------------------
  -- PASS 4: If your syntax might allow no parentheses or braces:
  -- e.g. \lim_{y->Infinity} 1/y => Limit[1/y, y->Infinity]
  ---------------------------------------------------------------------------
 eq = eq:gsub(
   "\\lim%s*_%s*%{([^}]+)%}%s*([^%s]+)",
   function(limit_block, expr)
     local var, a = limit_block:match("([%w]+)%s*->%s*(.+)")
     if var and a then
       return string.format("Limit[%s, %s -> %s]", expr, var, a)
     else
       return "\\lim_{" .. limit_block .. "}" .. expr
     end
   end
 )

  return eq
end


-- i ) function to escape backslashes and double quotes
local function escape_backslashes(eq)
  eq = eq:gsub("\\", "\\\\")
  eq = eq:gsub('"', '\\"')

  return eq
end


-- Main-functions to preprocess equation from LaTeX to WolframScript
function M.preprocess_equation(eq)
  io_utils("Preprocess Equ: Input => " .. eq)

  eq = basic_replacements(eq)
  io_utils("After basic replacements => " .. eq)

  eq = ordinary_derivative(eq)
  io_utils("After derivative replacement => " .. eq)

  eq = partial_derivative(eq)
  io_utils("After partial derivatives => " .. eq)

  eq = sum(eq)
  io_utils("After sums => " .. eq)

  eq = integral(eq)
  io_utils("After integrals => " .. eq)

  eq = replace_fractions(eq)
  io_utils("After fraction replacement => " .. eq)

  eq = function_calls(eq)
  io_utils("After function call replacement => " .. eq)

  eq = limits(eq)
  io_utils("After Limit replacement => " .. eq)

  eq = escape_backslashes(eq)
  io_utils("After escaping backslashes and quotes => " .. eq)

  io_utils("Final preprocessed equation => " .. eq)
  return eq
end

function M.parse_result(raw_result)
  if not raw_result then                                        -- If no raw_result is passed to the function, then
    return ""                                                   -- Return an empty string
  end
  raw_result = raw_result:gsub("[%z\1-\31]", "")                -- Remove non-printable characters
  raw_result = raw_result:match("^%s*(.-)%s*$") or raw_result   -- Trim whitespace
  return raw_result                                             -- Return a parsed result
end


-- Expose replacement functions under a 'tests' subtable for unit testing
M.tests = {
  basic_replacements = basic_replacements,
  ordinary_derivative = ordinary_derivative,
  partial_derivative = partial_derivative,
  sum = sum,
  integral = integral,
  replace_fractions = replace_fractions,
  function_calls = function_calls,
  limits = limits,
  escape_backslashes = escape_backslashes,
}


return M
