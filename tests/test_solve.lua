--------------------------------------------------------------------------------
-- test_solve.lua
--------------------------------------------------------------------------------

local parser     = require("tungsten.utils.parser")
local async      = require("tungsten.async")
local test_utils = require("tungsten.tests.test_utils")

local M = {}

function M.run_solve_for_variable_test()
  test_utils.log_header("Solve for Variable Test")

  local test_cases = {
    { "2x + 4 = 10", "x" },
    { "y^2 + 5y + 4 = 0", "y" },
    -- ...
  }

  local i = 1
  local function run_next()
    if i > #test_cases then
      return
    end
    local eq_latex, variable = test_cases[i][1], test_cases[i][2]
    i = i + 1

    local preprocessed = parser.preprocess_equation(eq_latex)
    preprocessed = preprocessed:gsub("([^=])=([^=])", "%1==%2")

    test_utils.append_log_line("Equation => " .. eq_latex)
    test_utils.append_log_line("Variable => " .. variable)
    test_utils.append_log_line("Preprocessed => " .. preprocessed)

    async.run_solve_async(preprocessed, variable, function(result, err)
      if err then
        test_utils.append_log_line("ERROR: " .. err)
      elseif not result or result:find("$Failed") then
        test_utils.append_log_line("ERROR: solve returned $Failed")
      else
        test_utils.append_log_line("Solution => " .. result)
      end
      run_next()
    end)
  end

  run_next()
end

return M
