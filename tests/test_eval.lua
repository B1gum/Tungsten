--------------------------------------------------------------------------------
-- test_eval.lua
-- Evaluate tests (like run_evaluate_test from original big file)
--------------------------------------------------------------------------------

local parser     = require("tungsten.utils.parser")
local async      = require("tungsten.async")
local test_utils = require("tungsten.tests.test_utils")

local M = {}

function M.run_evaluate_test()
  test_utils.log_header("Evaluate Test")

  local test_expressions = {
    "\\sin\\left(\\frac{\\pi}{4}\\right) + \\sin\\left(\\frac{\\pi}{4}\\right)",
    "\\int_{0}^{1} x^{2} \\, \\mathrm{d}x",
    "\\frac{\\mathrm{d}}{\\mathrm{d}y} y^2 + 2y - 8",
    "\\sqrt{x^2+1}",
    "\\tan\\left(\\frac{\\pi}{6}\\right)",
    "\\lim_{\\alpha \\to \\infty} \\frac{1}{\\alpha}",
    "\\frac{\\partial^2}{\\partial x \\partial y} \\sin(x \\cdot y)",
  }

  local i = 1
  local function run_next()
    if i > #test_expressions then
      return
    end
    local latex_expr = test_expressions[i]
    i = i + 1

    local preprocessed = parser.preprocess_equation(latex_expr)
    test_utils.append_log_line("Input => " .. latex_expr)
    test_utils.append_log_line("Preprocessed => " .. preprocessed)

    async.run_evaluation_async(preprocessed, false, function(result, err)
      if err then
        test_utils.append_log_line("ERROR: " .. err)
      elseif not result or result:find("$Failed") then
        test_utils.append_log_line("ERROR: evaluation returned $Failed")
      else
        test_utils.append_log_line("Result => " .. result)
      end
      run_next()
    end)
  end

  run_next()
end

return M
