--------------------------------------------------------------------------------
-- init.lua
-- Aggregates all test modules, sets up user commands, etc.
--------------------------------------------------------------------------------

local utils         = require("tungsten.tests.test_utils")
local eval          = require("tungsten.tests.test_eval")
local simplify      = require("tungsten.tests.test_simplify")
local solve         = require("tungsten.tests.test_solve")
local solve_system  = require("tungsten.tests.test_solve_system")
local taylor        = require("tungsten.tests.test_taylor")
local parser_unit   = require("tungsten.tests.test_parser_unit")

local suite_file = require("tungsten.tests.unit_test_suites")
local test_suites = suite_file.all_suites

local M = {}

-- A few convenience functions
function M.run_evaluate_test()           eval.run_evaluate_test()             end
function M.run_simplify_test()           simplify.run_simplify_test()         end
function M.run_solve_for_variable_test() solve.run_solve_for_variable_test()  end
function M.run_solve_system_test()       solve_system.run_solve_system_test() end
function M.run_taylor_test()             taylor.run_taylor_test()             end
function M.run_unit_tests()              parser_unit.run_parser_unit_tests()  end

-- Run all tests
function M.run_all_tests()
  utils.open_test_scratch_buffer()

  -- Async-based tests
  M.run_evaluate_test()
  M.run_simplify_test()
  M.run_solve_for_variable_test()
  M.run_solve_system_test()
  M.run_taylor_test()

  -- Parser unit tests
  M.run_unit_tests()

  utils.append_log_line("All test calls triggered. Results will appear here.")
end

-- Example: commands
function M.setup_commands()
  vim.api.nvim_create_user_command("TungstenAutoEvalTest", function()
    M.run_evaluate_test()
  end, { desc = "Run Evaluate test" })

  vim.api.nvim_create_user_command("TungstenAutoSimplifyTest", function()
    M.run_simplify_test()
  end, { desc = "Run Simplify test" })

  vim.api.nvim_create_user_command("TungstenSolveTest", function()
    M.run_solve_for_variable_test()
  end, { desc = "Run Solve test" })

  vim.api.nvim_create_user_command("TungstenSolveSystemTest", function()
    M.run_solve_system_test()
  end, { desc = "Run Solve System test" })

  vim.api.nvim_create_user_command("TungstenTaylorTest", function()
    M.run_taylor_test()
  end, { desc = "Run Taylor test" })

  vim.api.nvim_create_user_command("TungstenAllTests", function()
    M.run_all_tests()
  end, { desc = "Run ALL tests" })

  vim.api.nvim_create_user_command("TungstenUnitTests", function()
    M.run_unit_tests()
  end, { desc = "Run parser unit tests" })

  vim.api.nvim_create_user_command("TungstenTestSuite", function(opts)
    local suite_name = opts.args
    local suite_func = test_suites[suite_name]

    if not suite_func then
      -- if no matching test suite name, print an error and show possible completions
      vim.notify("No such test suite: " .. suite_name, vim.log.levels.ERROR)

      local msg = { "Available suites:" }
      for name, _ in pairs(test_suites) do
        table.insert(msg, "  " .. name)
      end
      -- You can either notify or echo them
      for _, line in ipairs(msg) do
        print(line)
      end
      return
    end

    -- If we do have the function, run it
    suite_func()
  end, {
    desc = "Run a specific Tungsten test suite by name",
    nargs = 1,
    complete = function(_, _, _)
      -- Return the list of suite names for completion
      local suggestions = {}
      for name, _ in pairs(test_suites) do
        table.insert(suggestions, name)
      end
      return suggestions
    end
  })
end

return M

