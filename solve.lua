--------------------------------------------------------------------------------
-- solve.lua
-- Manages single-equation and system-of-equations solves.
--------------------------------------------------------------------------------

local utils = require("wolfram.utils")
local async = require("wolfram.async")

local M = {}

--------------------------------------------------------------------------------
-- 1) Append solution asynchronously (single equation)
--------------------------------------------------------------------------------
function M.append_solution_async()
  local start_row, start_col = vim.fn.line("'<"), vim.fn.col("'<")
  local end_row,   end_col   = vim.fn.line("'>"), vim.fn.col("'>")
  local lines                = vim.fn.getline(start_row, end_row)

  -- Adjust first/last lines based on column selection
  lines[1]       = lines[1]:sub(start_col)
  lines[#lines]  = lines[#lines]:sub(1, end_col)
  local selection = table.concat(lines, "\n")

  utils.debug_print("Original selection for solve => " .. selection)

  -- (A) Extract equation and variable (e.g., "2x + 4 = 10, x")
  local equation, variable, err = utils.extract_equation_and_variable(selection)
  if err then
    vim.api.nvim_err_writeln("Error: " .. err)
    return
  end

  utils.debug_print("Equation => " .. equation)
  utils.debug_print("Variable => " .. variable)

  -- (B) Preprocess from LaTeX => Wolfram
  local preprocessed_eq = utils.preprocess_equation(equation)
  utils.debug_print("Preprocessed Equation => " .. preprocessed_eq)

  -- (C) Replace single '=' with '=='
  preprocessed_eq = preprocessed_eq:gsub("([^=])=([^=])", "%1==%2")
  utils.debug_print("Final solve equation => " .. preprocessed_eq)

  -- (D) Run solve asynchronously
  async.run_solve_async(preprocessed_eq, variable, function(raw_result, err)
    if err then
      vim.api.nvim_err_writeln("Error: " .. err)
      return
    end
    if not raw_result or raw_result:find("$Failed") then
      vim.api.nvim_err_writeln("Error: Unable to solve the equation.")
      return
    end

    -- (E) Unescape braces so that "\{\{x->3.\}\}" => "{{x->3.}}"
    raw_result = raw_result:gsub("\\{", "{"):gsub("\\}", "}")

    -- (F) Wolfram typically returns something like {{x->3.}} for a single solution.
    -- We'll parse with a balanced-braces pattern "(%b{})" to handle nested braces.
    local solutions = {}

    -- e.g., raw_result == "{{x->3.}}"
    -- for sol in raw_result:gmatch("(%b{})") do
    --   sol might be "{x->3.}" first pass, or if there's double braces, we might get the outer pair too
    -- end

    for sol in raw_result:gmatch("(%b{})") do
      -- strip outer braces:
      local content = sol:sub(2, -2)  -- remove the { and }
      local sol_pairs = {}
      -- now content might be "x->3." or "x->3., y->4." etc.
      for var, val in content:gmatch("(%w+)%s*->%s*([^,}]+)") do
        table.insert(sol_pairs, var .. " = " .. val)
      end
      if #sol_pairs > 0 then
        table.insert(solutions, table.concat(sol_pairs, ", "))
      end
    end

    -- (G) If we found no solutions (e.g. the pattern didn't match), fallback
    if #solutions == 0 then
      solutions = { variable .. " = " .. raw_result }
    end

    local solution_str = table.concat(solutions, ", ")
    utils.debug_print("Final solution => " .. solution_str)

    -- (H) Insert the solution below the selected lines
    vim.fn.append(end_row, solution_str)
  end)
end

--------------------------------------------------------------------------------
-- 2) Append system solution asynchronously
--------------------------------------------------------------------------------
function M.append_system_solution_async()
  local start_row, start_col = vim.fn.line("'<"), vim.fn.col("'<")
  local end_row,   end_col   = vim.fn.line("'>"), vim.fn.col("'>")
  local lines                = vim.fn.getline(start_row, end_row)

  lines[1]       = lines[1]:sub(start_col)
  lines[#lines]  = lines[#lines]:sub(1, end_col)
  local selection = table.concat(lines, "\n")
  utils.debug_print("Original selection for system solve => " .. selection)

  -- (A) Split selection into individual equations
  local equations = utils.split_equations(selection)
  if #equations < 2 then
    vim.api.nvim_err_writeln("Error: Please select at least two equations for a system.")
    return
  end

  -- (B) Preprocess each
  local preprocessed_equations = {}
  for i, eq in ipairs(equations) do
    utils.debug_print("Preprocessing equations[" .. i .. "] => " .. eq)
    preprocessed_equations[i] = utils.preprocess_equation(eq)
  end

  -- (C) Balanced bracket check
  for i, eq in ipairs(preprocessed_equations) do
    if not utils.is_balanced(eq) then
      vim.api.nvim_err_writeln("Error: Unbalanced brackets in equation " .. i)
      return
    end
  end

  -- (D) Replace single '=' => '=='
  local solve_equations = {}
  for i, eq in ipairs(preprocessed_equations) do
    solve_equations[i] = eq:gsub("([^=])=([^=])", "%1==%2")
  end

  -- (E) Extract variables from the preprocessed eqs
  local variables = utils.extract_variables(preprocessed_equations)
  if #variables == 0 then
    vim.api.nvim_err_writeln("Error: No variables found in the selected equations.")
    return
  end

  utils.debug_print("Preprocessed Equations for Solve => " .. table.concat(solve_equations, ", "))
  utils.debug_print("Variables => " .. table.concat(variables, ", "))

  -- (F) Solve system
  async.run_solve_system_async(solve_equations, variables, function(raw_result, err)
    if err then
      vim.api.nvim_err_writeln("Error: " .. err)
      return
    end
    if not raw_result or raw_result:find("$Failed") then
      vim.api.nvim_err_writeln("Error: Unable to solve the system of equations.")
      return
    end

    -- (G) Unescape braces for correct parsing
    raw_result = raw_result:gsub("\\{", "{"):gsub("\\}", "}")

    local solutions = {}
    for sol in raw_result:gmatch("(%b{})") do
      local content = sol:sub(2, -2)
      local sol_pairs = {}
      for var, val in content:gmatch("(%w+)%s*->%s*([^,}]+)") do
        table.insert(sol_pairs, var .. " = " .. val)
      end
      if #sol_pairs > 0 then
        table.insert(solutions, table.concat(sol_pairs, ", "))
      end
    end

    if #solutions == 0 then
      solutions = { "Solution: " .. raw_result }
    else
      for i, s in ipairs(solutions) do
        solutions[i] = "Solution " .. i .. ": " .. s
      end
    end

    local solution_str = table.concat(solutions, "\n")
    utils.debug_print("Final solution => " .. solution_str)

    vim.fn.append(end_row, solution_str)
  end)
end

--------------------------------------------------------------------------------
-- 3) Setup user commands
--------------------------------------------------------------------------------
function M.setup_commands()
  vim.api.nvim_create_user_command("WolframSolve", function()
    M.append_solution_async()
  end, {
    range = true,
    desc = "Solve the selected equation for a specified variable. Usage: equation, variable"
  })

  vim.api.nvim_create_user_command("WolframSolveSystem", function()
    M.append_system_solution_async()
  end, {
    range = true,
    desc = "Solve a system of selected equations."
  })
end

return M

