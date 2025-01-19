--------------------------------------------------------------------------------
-- test_simplify.lua
--------------------------------------------------------------------------------

local parser     = require("tungsten.utils.parser")
local async      = require("tungsten.async")
local test_utils = require("tungsten.tests.test_utils")

local M = {}

function M.run_simplify_test()
  test_utils.log_header("Simplify Test")

  local test_expressions = {
    "\\sin^2(x) + \\cos^2(x)",
    "\\ln(e^x)",
    -- ...
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

    async.run_simplify_async(preprocessed, false, function(result, err)
      if err then
        test_utils.append_log_line("ERROR: " .. err)
      elseif not result or result:find("$Failed") then
        test_utils.append_log_line("ERROR: simplify returned $Failed")
      else
        test_utils.append_log_line("Result => " .. result)
      end
      run_next()
    end)
  end

  run_next()
end

return M
