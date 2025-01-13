--------------------------------------------------------------------------------
-- tests.lua
-- Implements a test suite that logs outputs to a scratch buffer, running tests
-- sequentially (one at a time) to avoid kernel overload.
--------------------------------------------------------------------------------

-- 1) Setup
--------------------------------------------------------------------------------
local utils     = require("tungsten.utils")
local async     = require("tungsten.async")
local evaluate  = require("tungsten.evaluate")
local simplify  = require("tungsten.simplify")
local solve     = require("tungsten.solve")
local taylor    = require("tungsten.taylor")

local M = {}




-- 1) Utility functions
--------------------------------------------------------------------------------

-- a) Initialize buffer
--------------------------------------------------------------------------------
local test_bufnr = nil  -- Initialize variable to store the buffer number of the scratch buffer used for logging

local function open_test_scratch_buffer()
  if test_bufnr and vim.api.nvim_buf_is_valid(test_bufnr) then  -- If a test-buffer is already open, then
    return test_bufnr  -- Reuse it
  end

  -- Create new scratch buffer if none is open
  test_bufnr = vim.api.nvim_create_buf(false, true)                   -- (listed=false, scratch=true)
  vim.api.nvim_buf_set_option(test_bufnr, "bufhidden", "wipe")        -- bufhidden = wipe – The buffer is wiped fom memory when no longer displayed
  vim.api.nvim_buf_set_option(test_bufnr, "filetype", "tungstentest") -- filetype = tungstentest – Sets test-specific file-type
  vim.api.nvim_command("botright vsplit")                             -- Opens the buffer in a vertical split in the bottom right of the neovim window
  vim.api.nvim_set_current_buf(test_bufnr)                            -- Makes the newly created buffer the current buffer
  return test_bufnr
end


-- b) Add a line of text to the buffer
--------------------------------------------------------------------------------
local function append_log_line(msg)
  local bufnr = open_test_scratch_buffer()                  -- Sets the buffer to the test-buffer
  vim.api.nvim_buf_set_option(bufnr, "modifiable", true)    -- Temporarily sets the modifiable-flag to true
  vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, { msg }) -- Adds a line a the end
  vim.api.nvim_buf_set_option(bufnr, "modifiable", false)   -- Sets the modifiable-flag to false again
end


-- c) Format a header for the log
--------------------------------------------------------------------------------
local function log_header(title)
  append_log_line("")
  append_log_line("========================================")
  append_log_line("  " .. title)
  append_log_line("========================================")
end




-- 2) Evaluate Test 
--------------------------------------------------------------------------------
local function run_evaluate_test()  -- Function that executes a series of evaluation tests and logs the resuls 
  log_header("Evaluate Test")       -- Inserts a log_header with the title "Evaluate Test"

  local test_expressions = {        -- Define test-expressions in LaTex-syntax
    "\\sin\\left(\\frac{\\pi}{4}\\right) + \\sin\\left(\\frac{\\pi}{4}\\right)",
    "\\int_{0}^{1} x^{2} \\, \\mathrm{d}x",
    "\\frac{\\mathrm{d}}{\\mathrm{d}y} y^2 + 2y - 8",
    "\\sqrt{x^2+1}",
    "\\tan\\left(\\frac{\\pi}{6}\\right)",
    "\\lim_{\\alpha \\to \\infty} \\frac{1}{\\alpha}",
    "\\frac{\\partial^2}{\\partial x \\partial y} \\sin(x \\cdot y)",
  }

  local i = 1
  local function run_next()                   -- Handles sequential execution of commands to avoid overloading the Wolfram-kernel
    if i > #test_expressions then             -- When the loop-index surpasses the number of expressions exit the function
      return -- finished
    end
    local latex_expr = test_expressions[i]    -- Define an expression for the current loop-index
    i = i + 1                                 -- Increment the loop-index

    local preprocessed = utils.preprocess_equation(latex_expr)              -- Preprocess the equation with preprocess_equation
    append_log_line("Input => " .. latex_expr)                              -- Prints the input to the test-log buffer
    append_log_line("Preprocessed => " .. preprocessed)                     -- Prints the preprocessed equation to the test-log buffer

    async.run_evaluation_async(preprocessed, false, function(result, err)   -- Run the asynchronous evaluation function on the preprocessed equation
      if err then                                                           -- If an error occurs, then
        append_log_line("ERROR: " .. err)                                   -- Print the error to the test-log
      elseif not result or result:find("$Failed") then                      -- If no result is found, then
        append_log_line("ERROR: evaluation returned $Failed")               -- Print an error to the test-log
      else
        append_log_line("Result of evaluation of " .. latex_expr .. " => " .. result)   -- Else print the result to the test-log
      end
      -- proceed to next expression
      run_next()
    end)
  end

  run_next()  -- start the chain
end




-- 3) Simplify Test 
--------------------------------------------------------------------------------
local function run_simplify_test()  -- Function that executes a series of simplify tests and logs the results 
  log_header("Simplify Test")       -- Inserts a log_header with the title "Simplify Test"

  local test_expressions = {        -- Define test-expressions in LaTex-syntax
    "\\sin^2(x) + \\cos^2(x)",
    "\\ln(e^x)",
    "\\sin^4(x) - \\sin^2(x)\\cos^2(x) + \\cos^4(x)",
    "\\sqrt{x^2 + 2x + 1}",
    "\\frac{x^2 - 4}{x^2 - 2x + 1}",
    "\\ln(e^{x^2}) - 2x",
    "\\alpha + \\beta - \\beta"
  }

  local i = 1
  local function run_next()                 -- Handles sequential execution of commands to avoid overloading the Wolfram-kernel
    if i > #test_expressions then           -- When the loop-indes surpasses the number of expressions exit the function
      return
    end
    local latex_expr = test_expressions[i]  -- Define an expression for the current loop-index
    i = i + 1                               -- Increment the loop-index

    local preprocessed = utils.preprocess_equation(latex_expr)            -- Preprocess the equation with preprocess_equation
    append_log_line("Input => " .. latex_expr)                            -- Prints the input to the test-log buffer
    append_log_line("Preprocessed => " .. preprocessed)                   -- Prints the preprocessed equation to the test-log buffer

    async.run_simplify_async(preprocessed, false, function(result, err)   -- Runs the asynchronous siplify command on the preprocessed equation
      if err then                                                         -- If an error occurs, then
        append_log_line("ERROR: " .. err)                                 -- Print the error to the test-log
      elseif not result or result:find("$Failed") then                    -- If no result is found, then
        append_log_line("ERROR: simplify returned $Failed")               -- Print an error to the test-log
      else
        append_log_line("Result of evaluation of " .. latex_expr .. " => " .. result)   -- Else print the result to the test-log
      end
      run_next()
    end)
  end

  run_next()
end




-- 4) Solve for Variable Test
--------------------------------------------------------------------------------
local function run_solve_for_variable_test()  -- Function that executes a series of solve for variable tests and logs the results 
  log_header("Solve for Variable Test")       -- Inserts a log_header with the title "Solve for Variable Test"

  local test_cases = {                        -- Define test-expressions in LaTex-syntax
    { "2x + 4 = 10", "x" },
    { "y^2 + 5y + 4 = 0", "y" },
    { "z^3 = 8", "z" },
    { "e^x = 10", "x" },
    { "\\sin(x) = 1", "x" },
    { "\\frac{x}{2} = 2", "x" },
    { "x^2 + y = 8", "x" }
  }

  local i = 1
  local function run_next()   -- Handles sequential execution of commands to avoid overloading the Wolfram-kernel
    if i > #test_cases then   -- When the loop-indes surpasses the number of expressions exit the function
      return
    end
    local eq_latex, variable = test_cases[i][1], test_cases[i][2]         -- Define an expression for the current loop-index
    i = i + 1   -- Increment the loop-index

    local preprocessed = utils.preprocess_equation(eq_latex)              -- Preprocess the equation with preprocess_equation
    preprocessed = preprocessed:gsub("([^=])=([^=])", "%1==%2")           -- Substitute = for ==

    append_log_line("Equation => " .. eq_latex)                           -- Print the equation to be solved to the test-log
    append_log_line("Variable => " .. variable)                           -- Print the variable to be solved for to the test-log
    append_log_line("Preprocessed => " .. preprocessed)                   -- Print the preprocessed equation to the test-log

    async.run_solve_async(preprocessed, variable, function(result, err)   -- Runs the asynchronous solve sommand on the preprocessed equation
      if err then                                                         -- If an error occurs, then
        append_log_line("ERROR: " .. err)                                 -- Print the error to the test-log
      elseif not result or result:find("$Failed") then                    -- If no result is found, then
        append_log_line("ERROR: solve returned $Failed")                  -- Print an error to the test-log
      else
        append_log_line("Solution of " .. eq_latex .. " => " .. result)         -- Else print the result to the test-log
      end
      run_next()
    end)
  end

  run_next()
end




-- 5) Solve System of Equations Test (queue-based)
--------------------------------------------------------------------------------
local function run_solve_system_test()          -- Function that executes a series of solve system of equations tests and logs the results 
  log_header("Solve System of Equations Test")  -- Inserts a log_header with the title "Solve System of Equations Test"

  local systems = {                             -- Define test-expressions in LaTex-syntax
    { "x + y = 5", "x - y = 1" },
    { "x^2 + y^2 = 4", "x = y" },
    { "2x + y = 10", "x - y = 2" },
    { "x^2 + y = 7", "x + y^2 = 11" },
    { "2x + 3y = 6", "3x + 2y = 6" },
    { "2x + 3y + 2z = 8", "3x + 2y - 2z = 4", "\\frac{5z}{x} = 6" }
  }

  local i = 1
  local function run_next()   -- Handles sequential execution of commands to avoid overloading the Wolfram-kernel
    if i > #systems then      -- When the loop-indes surpasses the number of expressions exit the function
      return
    end

    local sys = systems[i]    -- Define an expression for the current loop-index
    i = i + 1                 -- Increment the loop-index

    local eqs_str = table.concat(sys, ", ")
    append_log_line("System => " .. eqs_str)  -- Prints the selected system of equation to the test-log

    local preproc = {}
    for _, eq_latex in ipairs(sys) do                       -- For each equation in the system of equations
      local eq_pre = utils.preprocess_equation(eq_latex)    -- Preprocess the equations with preprocess_equation
      eq_pre = eq_pre:gsub("([^=])=([^=])", "%1==%2")       -- Substitute = for ==
      table.insert(preproc, eq_pre)                         -- Store the preprocessed equation
    end

    append_log_line("Preprocessed => " .. table.concat(preproc, " ; "))     -- Print the preprocessed equation to the test-log

    local variables = { "x", "y" }                                          -- Set the variables as x and y
    async.run_solve_system_async(preproc, variables, function(result, err)  -- Solve the system of equations asynchronously
      if err then                                                           -- If an error occurs, then
        append_log_line("ERROR: " .. err)                                   -- Print the error to the test-log
      elseif not result or result:find("$Failed") then                      -- If no result is found, then
        append_log_line("ERROR: system solve returned $Failed")             -- Print an error to the test log
      else
        append_log_line("System Solution of " .. sys .. " => " .. result)                    -- Else print the result
      end
      run_next()
    end)
  end

  run_next()
end




-- 6) Taylor Series Test (queue-based)
--------------------------------------------------------------------------------
local function run_taylor_test()    -- Function that executes a series of taylor-expansion tests and logs the results 
  log_header("Taylor Series Test")  -- Inserts a log_header with the title "Taylor Series Test"

  local expansions = {              -- Define test-expressions in LaTex-syntax
    { "\\cos(x)", "x", "0", "5" },
    { "\\sin\\left(\\frac{x}{2}\\right)", "x", "0", "4" },
    { "e^x", "x", "1", "3" },
    { "\\ln\\left(1+x\\right)", "x", "0", "4" },
    { "\\sin^2(x)", "x", "0", "4" }
  }

  local i = 1
  local function run_next()   -- Handles sequential execution of commands to avoid overloading the Wolfram-kernel
    if i > #expansions then   -- When the loop-indes surpasses the number of expressions exit the function
      return
    end
    local latex_expr, var, x0, order = expansions[i][1], expansions[i][2], expansions[i][3], expansions[i][4]   -- Define an expression for the current loop-index
    i = i + 1   -- Increment the loop-index

    local preproc = utils.preprocess_equation(latex_expr)     -- Preprocess the equation with preprocess_equation
    local wolfram_code = string.format(                       -- Format the expression into WolframScript
      "ToString[Normal[Series[%s, {%s, %s, %s}]], TeXForm]",
      preproc, var, x0, order
    )

    append_log_line("Input => " .. latex_expr)                -- Print the input-equation to the test-log
    append_log_line("Preprocessed => " .. preproc)            -- Print the preprocessed equation to the test-log
    append_log_line("Wolfram code => " .. wolfram_code)       -- Print the generated WolframScript to the test-log

    async.run_wolframscript_async(                            -- Run the Taylor-function asynchronously
      { "wolframscript", "-code", wolfram_code, "-format", "OutputForm" },
      function(result, err)
        if err then                                           -- If an error occurs, then
          append_log_line("ERROR: " .. err)                   -- Print the error to the test-log
        elseif not result or result:find("$Failed") then      -- If no result is found
          append_log_line("ERROR: Taylor returned $Failed")   -- Print an error to the test-log
        else
          append_log_line("Taylor Series of " .. latex_expr .. " => " .. result)  -- Else print the result
        end
        run_next()
      end
    )
  end

  run_next()
end




-- 7) "Run All Tests" and Exports
--------------------------------------------------------------------------------
function M.run_evaluate_test()           run_evaluate_test()           end
function M.run_simplify_test()           run_simplify_test()           end
function M.run_solve_for_variable_test() run_solve_for_variable_test() end
function M.run_solve_system_test()       run_solve_system_test()       end
function M.run_taylor_test()             run_taylor_test()             end

function M.run_all_tests()
  open_test_scratch_buffer()
  run_evaluate_test()
  run_simplify_test()
  run_solve_for_variable_test()
  run_solve_system_test()
  run_taylor_test()
  append_log_line("All test calls have been triggered sequentially. Async results will appear above.")
end




-- 8) Setup user commands
--------------------------------------------------------------------------------
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
  end, { desc = "Run Taylor Series test" })

  vim.api.nvim_create_user_command("TungstenAllTests", function()
    M.run_all_tests()
  end, { desc = "Run all Tungsten tests" })
end

return M
