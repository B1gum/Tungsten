--------------------------------------------------------------------------------
-- test_parser_unit.lua
-- Contains all sub-tests for parser transformations: derivatives, sums, integrals,
-- fractions, function calls, limits, etc.
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- 1) Requires
--------------------------------------------------------------------------------
local parser      = require("tungsten.utils.parser")
local test_utils  = require("tungsten.tests.test_utils")   -- For logging
local test_runner = require("tungsten.tests.test_runner")  -- For run_unit_tests()

-- We'll return everything in 'M'
local M = {}


--------------------------------------------------------------------------------
-- 2) Sub-tests for each parser function
--------------------------------------------------------------------------------

-- a) basic_replacements
local function run_basic_replacements_tests()
  local test_cases = {
    {
      description = "Replace sine function",
      input = "\\sin(x)",
      expected = "Sin(x)",
    },
    {
      description = "Replace nested sine and cosine",
      input = "\\sin\\left(\\cos(2x)\\right)",
      expected = "Sin(Cos(2x))",
    },
    {
      description = "Replace products of trig-functions",
      input = "\\sin(x) \\cdot \\tan(x)",
      expected = "Sin(x) * Tan(x)",
    },
    {
      description = "Replace logarithm functions",
      input = "\\ln(x) + \\log(x)",
      expected = "Log(x) + Log10(x)",
    },
    {
      description = "Replace Greeks",
      input = "\\pi + \\alpha + \\tau + \\beta",
      expected = "Pi + Alpha + Tau + Beta",
    },
    {
      description = "Replace infinity symbol",
      input = "\\infty",
      expected = "Infinity",
    },
    {
      description = "Remove LaTeX spacing macros",
      input = "x \\cdot y \\,",
      expected = "x * y ",
    },
    {
      description = "Replace exponent with E",
      input = "e^{x}",
      expected = "E^{x}",
    },
    {
      description = "Replace square roots",
      input = "\\sqrt{e^x}",
      expected = "Sqrt{E^x}",
    },
    {
      description = "log^2",
      input = "\\log^2(x)",
      expected = "Log10(x)^2",
    },
    {
      description = "dx",
      input = "\\mathrm{d}x",
      expected = "dx",
    },
  }

  test_runner.run_unit_tests(parser.tests.basic_replacements, test_cases, "basic_replacements")
end

-- b) ordinary_derivative
local function run_ordinary_derivative_tests()
  local test_cases = {
    {
      description = "Simple derivative",
      input = "\\frac{d}{dx} (x^2)",
      expected = "D[(x^2), x]",
    },
    {
      description = "Derivative without parentheses",
      input = "\\frac{d}{dy} y^2 + 2y - 8",
      expected = "D[y^2 + 2y - 8, y]",
    },
    {
      description = "Nested derivative",
      input = "\\frac{d}{dz} \\sin(z)",
      expected = "D[\\sin(z), z]",
    },
  }
  test_runner.run_unit_tests(parser.tests.ordinary_derivative, test_cases, "ordinary_derivative")
end

-- c) partial_derivative
local function run_partial_derivative_tests()
  local test_cases = {
    {
      description = "Second-order partial derivative",
      input = "\\frac{\\partial^2}{\\partial x \\partial y} \\sin(x \\cdot y)",
      expected = "D[D[\\sin(x \\cdot y), x], y]",
    },
    {
      description = "First-order partial derivative",
      input = "\\frac{\\partial}{\\partial x} x^2 y",
      expected = "D[x^2 y, x]",
    },
    {
      description = "Partial derivative with exponent",
      input = "\\frac{\\partial^3}{\\partial x^2 \\partial y} x^2 y^3",
      expected = "D[D[D[x^2 y^3, x], x], y]",
    },
  }
  test_runner.run_unit_tests(parser.tests.partial_derivative, test_cases, "partial_derivative")
end

-- d) sum
local function run_sum_tests()
  local test_cases = {
    {
      description = "Simple sum with parentheses",
      input = "\\sum_{i=0}^{Infinity} i^2",
      expected = "Sum[i^2, {i, 0, Infinity}]",
    },
    {
      description = "Sum without parentheses",
      input = "\\sum_{j=1}^{n} j",
      expected = "Sum[j, {j, 1, n}]",
    },
    {
      description = "Sum with complex expression",
      input = "\\sum_{k=1}^{10} (k^3 + 2k)",
      expected = "Sum[k^3 + 2k, {k, 1, 10}]",
    },
  }
  test_runner.run_unit_tests(parser.tests.sum, test_cases, "sum")
end

-- e) integral
local function run_integral_tests()
  local test_cases = {
    {
      description = "Definite integral with {)",
      input = "\\int_{0}^{1} x^{2} dx",
      expected = "Integrate[x^{2}, {x, 0, 1}]",
    },
    {
      description = "Indefinite integral",
      input = "\\int e^x dx",
      expected = "Integrate[e^x, x]",
    },
    {
      description = "Definite integral with letters and {}",
      input = "\\int_{a}^{b} Sin(x) dx",
      expected = "Integrate[Sin(x), {x, a, b}]",
    },
    {
      description = "Definite integral without {}",
      input = "\\int_0^1 e^z dz",
      expected = "Integrate[e^z, {z, 0, 1}]",
    },
    {
      description = "Definite integral with letters and without {}",
      input = "\\int_a^b x^3 dx",
      expected = "Integrate[x^3, {x, a, b}]",
    },
    {
      description = "Empty integral",
      input = "\\int dy",
      expected = "Integrate[, y]",
    },
  }
  test_runner.run_unit_tests(parser.tests.integral, test_cases, "integral")
end

-- f) replace_fractions
local function run_replace_fractions_tests()
  local test_cases = {
    {
      description = "Simple fraction",
      input = "\\frac{a}{b}",
      expected = "(a/b)",
    },
    {
      description = "Nested fractions",
      input = "\\frac{\\frac{a}{b}}{c}",
      expected = "((a/b)/c)",
    },
    {
      description = "Fraction with operators",
      input = "\\frac{x + y}{z - w}",
      expected = "((x + y)/(z - w))",
    },
  }
  test_runner.run_unit_tests(parser.tests.replace_fractions, test_cases, "replace_fractions")
end

-- g) function_calls
local function run_function_calls_tests()
  local test_cases = {
    {
      description = "Function call with exponent",
      input = "Sin(x)^2",
      expected = "Sin[x]^2",
    },
    {
      description = "Nested function calls",
      input = "Log10(10 * x)",
      expected = "Log[10, 10 * x]",
    },
    {
      description = "Multiple function calls",
      input = "Exp(Log(x))",
      expected = "Exp[Log[x]]",
    },
  }
  test_runner.run_unit_tests(parser.tests.function_calls, test_cases, "function_calls")
end

-- h) limits
local function run_limits_tests()
  local test_cases = {
    {
      description = "Limit with exponent",
      input = "\\lim_{x -> 0} (x^2)^3",
      expected = "Limit[(x^2)^3, x -> 0]",
    },
    {
      description = "Limit without exponent",
      input = "\\lim_{y -> Infinity} 1/y",
      expected = "Limit[1/y, y -> Infinity]",
    },
    {
      description = "Limit with curly braces",
      input = "\\lim_{z -> 1}{z^2}",
      expected = "Limit[z^2, z -> 1]",
    },
  }
  test_runner.run_unit_tests(parser.tests.limits, test_cases, "limits")
end

-- i) escape_backslashes
local function run_escape_backslashes_tests()
  local test_cases = {
    {
      description = "Escape backslashes and quotes",
      input = "Path\\to\\file\"name\"",
      expected = "Path\\\\to\\\\file\\\"name\\\"",
    },
    {
      description = "No backslashes or quotes",
      input = "Simple string",
      expected = "Simple string",
    },
  }
  test_runner.run_unit_tests(parser.tests.escape_backslashes, test_cases, "escape_backslashes")
end

--------------------------------------------------------------------------------
-- 3) Top-level tests (preprocess_equation, parse_result)
--------------------------------------------------------------------------------

-- j) test the entire pipeline: M.preprocess_equation(eq)
local function run_preprocess_equation_tests()
  local test_cases = {
    {
      description = "All transformations in one shot",
      input = "\\sin\\left(\\cos(2x)\\right) + \\frac{\\mathrm{d}}{\\mathrm{d}x}(x^2) + \\frac{a}{b}",
      expected = "Sin[Cos[2x]] + D[x^2, x] + (a/b)",
    },
    {
      description = "Integral + sum + partial derivative",
      input = "\\int_{0}^{1} x^2 dx + \\sum_{k=0}^{\\infty} (k) + \\frac{\\partial}{\\partial x} e^x",
      expected = "Integrate[x^2, {x, 0, 1}] + Sum[k, {k, 0, Infinity}] + D[E^x, x]",
    },
    {
      description = "Limits + fraction + trig",
      input = "\\lim_{y -> \\infty} \\frac{\\sin(y)}{y}",
      expected = "Limit[Sin[y]/y, y -> Infinity]",
    },
    {
      description = "Empty integrand with indefinite integral + partial derivative 2nd order + backslash escaping",
      input = "\\int d\\theta + \\frac{\\partial^2}{\\partial x^2} \\sqrt{x}",
      expected = "Integrate[, \\theta] + D[D[Sqrt{x}, x], x]",
    },
  }
  test_runner.run_unit_tests(parser.preprocess_equation, test_cases, "preprocess_equation")
end

-- k) test parse_result
local function run_parse_result_tests()
  local test_cases = {
    {
      description = "Nil input => returns empty string",
      input = nil,
      expected = "",
    },
    {
      description = "Nonprintable chars stripped, leading/trailing spaces trimmed",
      input = "  \t\n  \001Hello World\002  \r\n",
      expected = "Hello World",
    },
    {
      description = "No changes if normal string with no leading/trailing whitespace",
      input = "Hello, I'm fine.",
      expected = "Hello, I'm fine.",
    },
    {
      description = "String with only whitespace becomes empty",
      input = "   \t\n\r",
      expected = "",
    },
  }
  test_runner.run_unit_tests(parser.parse_result, test_cases, "parse_result")
end

--------------------------------------------------------------------------------
-- 4) Suite-Table
--    This is a local table mapping suite names to the local test functions above.
--------------------------------------------------------------------------------
local test_suites = {
  basic_replacements     = run_basic_replacements_tests,
  ordinary_derivative    = run_ordinary_derivative_tests,
  partial_derivative     = run_partial_derivative_tests,
  sum                    = run_sum_tests,
  integral               = run_integral_tests,
  replace_fractions      = run_replace_fractions_tests,
  function_calls         = run_function_calls_tests,
  limits                 = run_limits_tests,
  escape_backslashes     = run_escape_backslashes_tests,
  preprocess_equation    = run_preprocess_equation_tests,
  parse_result           = run_parse_result_tests,
}

--------------------------------------------------------------------------------
-- 5) Public interface
--------------------------------------------------------------------------------

-- a) Run ALL parser sub-tests in one go
function M.run_parser_unit_tests()
  test_utils.log_header("Parser Unit Tests")
  run_basic_replacements_tests()
  run_ordinary_derivative_tests()
  run_partial_derivative_tests()
  run_sum_tests()
  run_integral_tests()
  run_replace_fractions_tests()
  run_function_calls_tests()
  run_limits_tests()
  run_escape_backslashes_tests()
  run_preprocess_equation_tests()
  run_parse_result_tests()
end

-- b) Run ONE parser sub-test by name
function M.run_one_parser_test(suite_name)
  test_utils.open_test_scratch_buffer()

  local f = test_suites[suite_name]
  if f then
    f()
  else
    test_utils.append_log_line("[ERROR] No such parser sub-test suite: " .. suite_name)
    test_utils.append_log_line("Valid names:")
    for name, _ in pairs(test_suites) do
      test_utils.append_log_line("  " .. name)
    end
  end
end

-- This function returns the ENTIRE test_suites table, so the aggregator
-- can look up sub-tests by name, e.g. "basic_replacements", "sum", etc.
function M.get_suites()
  return test_suites
end

return M

