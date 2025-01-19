--------------------------------------------------------------------------------
-- tests.lua
-- Implements a test suite that logs outputs to a scratch buffer, running tests
-- sequentially (one at a time) to avoid kernel overload.
--------------------------------------------------------------------------------

-- 1) Setup
--------------------------------------------------------------------------------
local parser = require("tungsten.utils.parser")
local async     = require("tungsten.async")

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


-- d) Unit Test Utility Functions
--------------------------------------------------------------------------------

-- Function to run a single test case
local function run_test_case(function_under_test, input, expected_output, test_name)
  local actual_output = function_under_test(input)
  if actual_output == expected_output then
    append_log_line("[PASS] " .. test_name)
  else
    append_log_line("[FAIL] " .. test_name)
    append_log_line("  Input:    " .. input)
    append_log_line("  Expected: " .. expected_output)
    append_log_line("  Got:      " .. actual_output)
  end
end

-- Function to run multiple test cases for a specific function
local function run_unit_tests(func_table, test_cases, function_name)
  log_header("Unit Tests for " .. function_name)
  for _, test in ipairs(test_cases) do
    run_test_case(func_table, test.input, test.expected, test.description)
  end
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

    local preprocessed = parser.preprocess_equation(latex_expr)              -- Preprocess the equation with preprocess_equation
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

    local preprocessed = parser.preprocess_equation(latex_expr)            -- Preprocess the equation with preprocess_equation
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

    local preprocessed = parser.preprocess_equation(eq_latex)              -- Preprocess the equation with preprocess_equation
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
      local eq_pre = parser.preprocess_equation(eq_latex)    -- Preprocess the equations with preprocess_equation
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

    local preproc = parser.preprocess_equation(latex_expr)     -- Preprocess the equation with preprocess_equation
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



-- 7) Unit Tests for Replacement Functions
--------------------------------------------------------------------------------

-- a) Test for basic_replacements
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

  run_unit_tests(parser.tests.basic_replacements, test_cases, "basic_replacements")
end


-- b) Test for ordinary_derivative
local function run_ordinary_derivative_tests()
  local test_cases = {
    {
      description = "Simple derivative",
      input = "\\frac{\\mathrm{d}}{\\mathrm{d}x} (x^2)",
      expected = "D[(x^2), x]",
    },
    {
      description = "Derivative without parentheses",
      input = "\\frac{\\mathrm{d}}{\\mathrm{d}y} y^2 + 2y - 8",
      expected = "D[y^2 + 2y - 8, y]",
    },
    {
      description = "Nested derivative",
      input = "\\frac{\\mathrm{d}}{\\mathrm{d}z} \\sin(z)",
      expected = "D[\\sin(z), z]",
    },
  }

  run_unit_tests(parser.tests.ordinary_derivative, test_cases, "ordinary_derivative")
end


-- c) Test for partial_derivative
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

  run_unit_tests(parser.tests.partial_derivative, test_cases, "partial_derivative")
end


-- d) Test for sum
local function run_sum_tests()
  local test_cases = {
    {
      description = "Simple sum with parentheses",
      input = "\\sum_{i=0}^{\\infty} (i^2)",
      expected = "Sum[(i^2), {i, 0, Infinity}]",
    },
    {
      description = "Sum without parentheses",
      input = "\\sum_{j=1}^{n} j",
      expected = "Sum[j, {j, 1, n}]",
    },
    {
      description = "Sum with complex expression",
      input = "\\sum_{k=1}^{10} k^3 + 2k",
      expected = "Sum[k^3 + 2k, {k, 1, 10}]",
    },
  }

  run_unit_tests(parser.tests.sum, test_cases, "sum")
end


-- e) Test for integral
local function run_integral_tests()
  local test_cases = {
    {
      description = "Definite integral with {)",
      -- MUST double-escape or use a long-bracket
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
      expected = "Integrate[, y]",  -- Adjust as needed based on your logic
    },
  }

  run_unit_tests(parser.tests.integral, test_cases, "integral")
end

-- f) Test for replace_fractions
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

  run_unit_tests(parser.tests.replace_fractions, test_cases, "replace_fractions")
end


-- g) Test for function_calls
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

  run_unit_tests(parser.tests.function_calls, test_cases, "function_calls")
end


-- h) Test for limits
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

  run_unit_tests(parser.tests.limits, test_cases, "limits")
end


-- i) Test for escape_backslashes
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

  run_unit_tests(parser.tests.escape_backslashes, test_cases, "escape_backslashes")
end



-- 8) "Run All Tests" and Exports
--------------------------------------------------------------------------------
function M.run_evaluate_test()           run_evaluate_test()           end
function M.run_simplify_test()           run_simplify_test()           end
function M.run_solve_for_variable_test() run_solve_for_variable_test() end
function M.run_solve_system_test()       run_solve_system_test()       end
function M.run_taylor_test()             run_taylor_test()             end

function M.run_unit_tests()
  run_basic_replacements_tests()
  run_ordinary_derivative_tests()
  run_partial_derivative_tests()
  run_sum_tests()
  run_integral_tests()
  run_replace_fractions_tests()
  run_function_calls_tests()
  run_limits_tests()
  run_escape_backslashes_tests()
end

function M.run_all_tests()
  open_test_scratch_buffer()
  run_evaluate_test()
  run_simplify_test()
  run_solve_for_variable_test()
  run_solve_system_test()
  run_taylor_test()
  run_unit_tests()  -- Run unit tests
  append_log_line("All test calls have been triggered sequentially. Async results will appear on the right.")
end



-- 9) Setup user commands
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

  vim.api.nvim_create_user_command("TungstenUnitTests", function()
    M.run_unit_tests()
  end, { desc = "Run Unit Tests for Replacement Functions" })
end

return M
