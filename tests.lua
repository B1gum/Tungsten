--------------------------------------------------------------------------------
-- Implements a test suite that logs outputs to a scratch buffer, running tests
-- sequentially (one at a time) to avoid kernel overload.
--------------------------------------------------------------------------------

local utils     = require("tungsten.utils")
local async     = require("tungsten.async")
local evaluate  = require("tungsten.evaluate")
local simplify  = require("tungsten.simplify")
local solve     = require("tungsten.solve")
local plot      = require("tungsten.plot")
local taylor    = require("tungsten.taylor")

local M = {}

--------------------------------------------------------------------------------
-- 0) Utility: Scratch buffer for log output
--------------------------------------------------------------------------------
local test_bufnr = nil

local function open_test_scratch_buffer()
  if test_bufnr and vim.api.nvim_buf_is_valid(test_bufnr) then
    return test_bufnr  -- Reuse if open
  end
  -- Create new scratch buffer
  test_bufnr = vim.api.nvim_create_buf(false, true)  -- (listed=false, scratch=true)
  vim.api.nvim_buf_set_option(test_bufnr, "bufhidden", "wipe")
  vim.api.nvim_buf_set_option(test_bufnr, "filetype", "tungstentest")
  vim.api.nvim_command("botright vsplit") -- or split/tabnew
  vim.api.nvim_set_current_buf(test_bufnr)
  return test_bufnr
end

local function append_log_line(msg)
  local bufnr = open_test_scratch_buffer()
  vim.api.nvim_buf_set_option(bufnr, "modifiable", true)
  vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, { msg })
  vim.api.nvim_buf_set_option(bufnr, "modifiable", false)
end

local function log_header(title)
  append_log_line("")
  append_log_line("========================================")
  append_log_line("  " .. title)
  append_log_line("========================================")
end

--------------------------------------------------------------------------------
-- 1) Evaluate Test (multiple expressions, but queue-based)
--------------------------------------------------------------------------------
local function run_evaluate_test()
  log_header("Evaluate Test")

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
      return -- finished
    end
    local latex_expr = test_expressions[i]
    i = i + 1

    local preprocessed = utils.preprocess_equation(latex_expr)
    append_log_line("Input => " .. latex_expr)
    append_log_line("Preprocessed => " .. preprocessed)

    async.run_evaluation_async(preprocessed, false, function(result, err)
      if err then
        append_log_line("ERROR: " .. err)
      elseif not result or result:find("$Failed") then
        append_log_line("ERROR: evaluation returned $Failed")
      else
        append_log_line("Result => " .. result)
      end
      -- proceed to next expression
      run_next()
    end)
  end

  run_next()  -- start the chain
end

--------------------------------------------------------------------------------
-- 2) Simplify Test (queue-based)
--------------------------------------------------------------------------------
local function run_simplify_test()
  log_header("Simplify Test")

  local test_expressions = {
    "\\sin^2(x) + \\cos^2(x)",
    "\\ln(e^x)",
    "\\sin^4(x) - \\sin^2(x)\\cos^2(x) + \\cos^4(x)",
    "\\sqrt{x^2 + 2x + 1}",
    "\\frac{x^2 - 4}{x^2 - 2x + 1}",
    "\\ln(e^{x^2}) - 2x",
    "\\alpha + \\beta - \\beta"
  }

  local i = 1
  local function run_next()
    if i > #test_expressions then
      return
    end
    local latex_expr = test_expressions[i]
    i = i + 1

    local preprocessed = utils.preprocess_equation(latex_expr)
    append_log_line("Input => " .. latex_expr)
    append_log_line("Preprocessed => " .. preprocessed)

    async.run_simplify_async(preprocessed, false, function(result, err)
      if err then
        append_log_line("ERROR: " .. err)
      elseif not result or result:find("$Failed") then
        append_log_line("ERROR: simplify returned $Failed")
      else
        append_log_line("Result => " .. result)
      end
      run_next()
    end)
  end

  run_next()
end

--------------------------------------------------------------------------------
-- 3) Solve for Variable Test (queue-based)
--------------------------------------------------------------------------------
local function run_solve_for_variable_test()
  log_header("Solve for Variable Test")

  local test_cases = {
    { "2x + 4 = 10", "x" },
    { "y^2 + 5y + 4 = 0", "y" },
    { "z^3 = 8", "z" },
    { "e^x = 10", "x" },
    { "\\sin(x) = 1", "x" },
    { "\\frac{x}{2} = 2", "x" },
    { "x^2 + y = 8", "x" }
  }

  local i = 1
  local function run_next()
    if i > #test_cases then
      return
    end
    local eq_latex, variable = test_cases[i][1], test_cases[i][2]
    i = i + 1

    local preprocessed = utils.preprocess_equation(eq_latex)
    -- Insert '==' for a direct solve
    preprocessed = preprocessed:gsub("([^=])=([^=])", "%1==%2")

    append_log_line("Equation => " .. eq_latex)
    append_log_line("Variable => " .. variable)
    append_log_line("Preprocessed => " .. preprocessed)

    async.run_solve_async(preprocessed, variable, function(result, err)
      if err then
        append_log_line("ERROR: " .. err)
      elseif not result or result:find("$Failed") then
        append_log_line("ERROR: solve returned $Failed")
      else
        append_log_line("Solution => " .. result)
      end
      run_next()
    end)
  end

  run_next()
end

--------------------------------------------------------------------------------
-- 4) Solve System of Equations Test (queue-based)
--------------------------------------------------------------------------------
local function run_solve_system_test()
  log_header("Solve System of Equations Test")

  local systems = {
    { "x + y = 5", "x - y = 1" },
    { "x^2 + y^2 = 4", "x = y" },
    { "2x + y = 10", "x - y = 2" },
    { "x^2 + y = 7", "x + y^2 = 11" },
    { "2x + 3y = 6", "3x + 2y = 6" },
    { "2x + 3y + 2z = 8", "3x + 2y - 2z = 4", "\\frac{5z}{x} = 6" }
  }

  local i = 1
  local function run_next()
    if i > #systems then
      return
    end

    local sys = systems[i]
    i = i + 1

    local eqs_str = table.concat(sys, ", ")
    append_log_line("System => " .. eqs_str)

    local preproc = {}
    for _, eq_latex in ipairs(sys) do
      local eq_pre = utils.preprocess_equation(eq_latex)
      eq_pre = eq_pre:gsub("([^=])=([^=])", "%1==%2")
      table.insert(preproc, eq_pre)
    end

    append_log_line("Preprocessed => " .. table.concat(preproc, " ; "))

    local variables = { "x", "y" }
    async.run_solve_system_async(preproc, variables, function(result, err)
      if err then
        append_log_line("ERROR: " .. err)
      elseif not result or result:find("$Failed") then
        append_log_line("ERROR: system solve returned $Failed")
      else
        append_log_line("System Solution => " .. result)
      end
      run_next()
    end)
  end

  run_next()
end

--------------------------------------------------------------------------------
-- 5) Plot Test (queue-based, single-string approach)
--------------------------------------------------------------------------------
local function run_plot_test()
  log_header("Plot Test")

  local plot_tests = {
    "\\sin(x) [-Pi, Pi] {r}",
    "\\cos^2(x) [-2*Pi, 2*Pi] {b}",
    "x^3 - x, x^2 + 2 [-3, 3] {g--, r-}",
    "e^x [-1, 2; -2, 8] {15}",
    "\\tan(x \\cdot y) [-Pi/2, Pi/2] {--}",
  }

  local i = 1
  local function run_next()
    if i > #plot_tests then
      return
    end

    local plot_string = plot_tests[i]
    i = i + 1

    -- Maybe generate a pdf name based on index i
    local pdf_name = string.format("plot_test_%d.pdf", i)

    append_log_line("Plot Selection => " .. plot_string)
    append_log_line("Output File => " .. pdf_name)

    async.run_plot_async(plot_string, pdf_name, function(err)
      if err then
        append_log_line("ERROR: " .. err)
      else
        append_log_line("Plot test succeeded. Output => " .. pdf_name)
        append_log_line("Include via \\includegraphics[width=0.5\\textwidth]{" .. pdf_name .. "}")
      end
      run_next()
    end)
  end

  run_next()
end


--------------------------------------------------------------------------------
-- 6) Taylor Series Test (queue-based)
--------------------------------------------------------------------------------
local function run_taylor_test()
  log_header("Taylor Series Test")

  local expansions = {
    { "\\cos(x)", "x", "0", "5" },
    { "\\sin\\left(\\frac{x}{2}\\right)", "x", "0", "4" },
    { "e^x", "x", "1", "3" },
    { "\\ln\\left(1+x\\right)", "x", "0", "4" },
    { "\\sin^2(x)", "x", "0", "4" }
  }

  local i = 1
  local function run_next()
    if i > #expansions then
      return
    end
    local latex_expr, var, x0, order = expansions[i][1], expansions[i][2], expansions[i][3], expansions[i][4]
    i = i + 1

    local preproc = utils.preprocess_equation(latex_expr)
    local wolfram_code = string.format(
      "ToString[Normal[Series[%s, {%s, %s, %s}]], TeXForm]",
      preproc, var, x0, order
    )

    append_log_line("Input => " .. latex_expr)
    append_log_line("Preprocessed => " .. preproc)
    append_log_line("Wolfram code => " .. wolfram_code)

    async.run_wolframscript_async(
      { "wolframscript", "-code", wolfram_code, "-format", "OutputForm" },
      function(result, err)
        if err then
          append_log_line("ERROR: " .. err)
        elseif not result or result:find("$Failed") then
          append_log_line("ERROR: Taylor returned $Failed")
        else
          append_log_line("Taylor Series => " .. result)
        end
        run_next()
      end
    )
  end

  run_next()
end

--------------------------------------------------------------------------------
-- 7) "Run All Tests" and Exports
--------------------------------------------------------------------------------
function M.run_evaluate_test()           run_evaluate_test()           end
function M.run_simplify_test()           run_simplify_test()           end
function M.run_solve_for_variable_test() run_solve_for_variable_test() end
function M.run_solve_system_test()       run_solve_system_test()       end
function M.run_plot_test()              run_plot_test()               end
function M.run_taylor_test()            run_taylor_test()             end

function M.run_all_tests()
  open_test_scratch_buffer()
  run_evaluate_test()
  run_simplify_test()
  run_solve_for_variable_test()
  run_solve_system_test()
  run_plot_test()
  run_taylor_test()
  append_log_line("All test calls have been triggered sequentially. Async results will appear above.")
end

--------------------------------------------------------------------------------
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

  vim.api.nvim_create_user_command("TungstenPlotTest", function()
    M.run_plot_test()
  end, { desc = "Run Plot test" })

  vim.api.nvim_create_user_command("TungstenTaylorTest", function()
    M.run_taylor_test()
  end, { desc = "Run Taylor Series test" })

  vim.api.nvim_create_user_command("TungstenAllTests", function()
    M.run_all_tests()
  end, { desc = "Run all Tungsten tests" })
end

return M
