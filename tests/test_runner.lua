--------------------------------------------------------------------------------
-- test_runner.lua
-- Generic test-running utilities: run_test_case, run_unit_tests
--------------------------------------------------------------------------------

local test_utils = require("tungsten.tests.test_utils")

local M = {}

-- Run a single test case
-- function_under_test is a function
-- input, expected_output, test_name are strings
function M.run_test_case(function_under_test, input, expected_output, test_name)
  local actual_output = function_under_test(input)
  if actual_output == expected_output then
    test_utils.append_log_line("[PASS] " .. test_name)
  else
    test_utils.append_log_line("[FAIL] " .. test_name)
    test_utils.append_log_line("  Input:    " .. input)
    test_utils.append_log_line("  Expected: " .. expected_output)
    test_utils.append_log_line("  Got:      " .. actual_output)
  end
end

-- Run multiple test cases for a specific function
function M.run_unit_tests(func_table, test_cases, function_name)
  test_utils.log_header("Unit Tests for " .. function_name)
  for _, test in ipairs(test_cases) do
    M.run_test_case(func_table, test.input, test.expected, test.description)
  end
end

return M
