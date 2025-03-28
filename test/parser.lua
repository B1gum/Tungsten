-- test/parser.lua
-- Test script for the LPeg parser with comprehensive test cases.
----------------------------------------------------------
local parser = require("tungsten.parser.LPeg_parser")
local AST = require("tungsten.parser.AST")
local inspect = require("vim.inspect")
local config = require("tungsten.config")

-- Helper to remove newlines from a string.
local function sanitize(str)
  return str:gsub("\n", " ")
end

-- Test cases grouped by rule:
local test_expressions = {
  -- 1. Basic Arithmetic and Variables:
  "1+2",                          -- Test 1.1: Simple addition
  "3*4-5",                        -- Test 1.2: Multiplication then subtraction
  "x^2 + 3",                      -- Test 1.3: Exponentiation and addition

  -- 2. Fractions:
  "\\frac{1}{2}",                 -- Test 2.1: Simple fraction
  "\\frac{x+1}{x-1}",             -- Test 2.2: Fraction with expressions
  "\\frac{3.14}{\\pi}",           -- Test 2.3: Fraction using constant

  -- 3. Derivatives:
  "\\frac{\\mathrm{d}}{\\mathrm{d}x}{x^2}",       -- Test 3.1: First derivative of a polynomial
  "\\frac{\\mathrm{d}}{\\mathrm{d}y}{\\sin(y)}",    -- Test 3.2: Derivative of a function call
  "\\frac{\\mathrm{d}}{\\mathrm{d}z}{z^3+2z}",      -- Test 3.3: More complex derivative

  -- 4. Integrals:
  "\\int_{0}^{1} \\sin(x) \\, \\mathrm{d}x",       -- Test 4.1: Standard definite integral of sin(x)
  "\\int_{0}^{\\pi} \\cos(x) \\, dx",               -- Test 4.2: Definite integral with plain differential
  "\\int_{-1}^{1} \\frac{1}{1+x^2} \\, \\mathrm{d}x", -- Test 4.3: Integral with fraction

  -- 5. Limits:
  "\\lim_{x \\to 0^{+}}{\\frac{1}{x}}",            -- Test 5.1: One-sided limit from above for 1/x
  "\\lim_{x \\to \\infty}{\\frac{1}{x}}",           -- Test 5.2: Limit as x→∞
  "\\lim_{x \\to 0}{\\frac{\\sin(x)}{x}}",           -- Test 5.3: Classic limit (should yield 1)

  -- 6. Function Calls:
  "\\sin(x)",                      -- Test 6.1: Function call (should become Sin[x])
  "\\cos(x+1)",                    -- Test 6.2: Function call with arithmetic argument
  "\\log(x)",                      -- Test 6.3: Function call (should become Log[x])

  -- 7. Greek Letters and Constants:
  "\\alpha + \\beta",              -- Test 7.1: Expression combining Greek letters
  "\\Gamma(x)",                    -- Test 7.2: Function call with uppercase Greek letter
  "\\Delta + \\theta^2",            -- Test 7.3: Expression mixing Greek letters and exponentiation

  -- 8. Complex Combinations (Covering Multiple Rules):
  "x^2 + \\sin(x) - \\frac{1}{\\pi}", -- Test 8.1: Exponentiation, function call, and fraction with constant
  "\\int_{0}^{\\pi}\\sin(x) \\, \\mathrm{d}x + \\lim_{x \\to 0}{\\frac{\\sin(x)}{x}}", -- Test 8.2: Integral plus a limit
  "\\frac{\\mathrm{d}}{\\mathrm{d}x}{\\Gamma(x)} + \\cos(x)", -- Test 8.3: Derivative of a function call with Greek letter and separate function call
}

local results = {}
local failed = false

for _, expr in ipairs(test_expressions) do
  local status, ast = pcall(parser.parse_expr, expr)
  if status and ast then
    if config.debug then
      table.insert(results, "Expression: " .. expr)
      table.insert(results, "AST: " .. sanitize(inspect(ast)))
      local wolfram_expr = AST.toWolfram(ast)
      table.insert(results, "WolframScript: " .. wolfram_expr)
      table.insert(results, string.rep("-", 40))
    end
    -- If not debugging, we log nothing for passing tests.
  else
    failed = true
    table.insert(results, "Expression: " .. expr .. " failed to parse.")
    table.insert(results, string.rep("-", 40))
  end
end

if not config.debug and not failed then
  results = { "All tests passed." }
end

-- Create a new scratch buffer and set its contents to the test results.
local buf = vim.api.nvim_create_buf(false, true) -- unlisted, scratch buffer
vim.api.nvim_buf_set_lines(buf, 0, -1, false, results)

-- Open a new vertical split window and load the buffer.
vim.api.nvim_command("botright vsplit")
vim.api.nvim_win_set_buf(0, buf)

