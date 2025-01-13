--------------------------------------------------------------------------------
-- solve.lua
-- Manages single-equation and system-of-equations solves.
--------------------------------------------------------------------------------

-- 1) Setup
--------------------------------------------------------------------------------
local utils = require("tungsten.utils")
local async = require("tungsten.async")

local M = {}




-- 2) Append solution asynchronously (single equation)
--------------------------------------------------------------------------------
function M.append_solution_async()
  -- a) Extract visual selection
  ------------------------------------------------------------------------------
  local start_row, start_col = vim.fn.line("'<"), vim.fn.col("'<")  -- Extracts the start of the visual selection
  local end_row,   end_col   = vim.fn.line("'>"), vim.fn.col("'>")  -- Extracts the end of the visual selection
  local lines                = vim.fn.getline(start_row, end_row)   -- lines is the rows in the visual selection

  lines[1]       = lines[1]:sub(start_col)                          -- Trim whitespace before visual selection
  lines[#lines]  = lines[#lines]:sub(1, end_col)                    -- Trim whitespace after visual selection
  local selection = table.concat(lines, "\n")                       -- Concatenates the selection into a single string with rows seperated by \n

  utils.debug_print("Original selection for solve => " .. selection)  -- (Optionally) prints the original selection for the solve-command


  -- b) Extract equation and variable (e.g., "2x + 4 = 10, x")
  ------------------------------------------------------------------------------
  local equation, variable, err = utils.extract_equation_and_variable(selection)  -- Extract equation and variable with utility-function
  if err then                                   -- If an error occus, then
    vim.api.nvim_err_writeln("Error: " .. err)  -- Print an error message to the error-log
    return
  end

  utils.debug_print("Equation => " .. equation) -- (Optionally) prints the extracted equation
  utils.debug_print("Variable => " .. variable) -- (Optionally) prints the extracted variable


  -- c) Preprocess from LaTeX => Wolfram
  ------------------------------------------------------------------------------
  local preprocessed_eq = utils.preprocess_equation(equation)       -- Proprocess the equation with preprocess_equation
  utils.debug_print("Preprocessed Equation => " .. preprocessed_eq) -- (Optionally) print the preprocessed equation

  preprocessed_eq = preprocessed_eq:gsub("([^=])=([^=])", "%1==%2") -- Substitute = for == to align with WolframScript-syntax
  utils.debug_print("Final solve equation => " .. preprocessed_eq)  -- (Optionally) print the final preprocessed equation


  -- d) Run solve asynchronously
  ------------------------------------------------------------------------------
  async.run_solve_async(preprocessed_eq, variable, function(raw_result, err)  -- call function to run the solve_command asynchronously
    if err then                                                         -- If an error occurs, then
      vim.api.nvim_err_writeln("Error: " .. err)                        -- Print the error-message to the error-log
      return
    end
    if not raw_result or raw_result:find("$Failed") then                -- If no result is found, then
      vim.api.nvim_err_writeln("Error: Unable to solve the equation.")  -- Print an error-message to the error-log
      return
    end

    -- e) Unescape braces so that "\{\{x->3.\}\}" => "{{x->3.}}"
    ----------------------------------------------------------------------------
    raw_result = raw_result:gsub("\\{", "{"):gsub("\\}", "}")


    -- f) Post-process result
    ----------------------------------------------------------------------------
    local solutions = {}
    for sol in raw_result:gmatch("(%b{})") do   -- Loop through balanced brackets to handle nested braces
      local content = sol:sub(2, -2)            -- Strip outer braces
      local sol_pairs = {}
      -- now content might be "x->3." or "x->3., y->4." etc.
      for var, val in content:gmatch("(%w+)%s*->%s*([^,}]+)") do  -- Extract variable and value from output
        table.insert(sol_pairs, var .. " = " .. val)              -- Format solutions in sol_pairs
      end
      if #sol_pairs > 0 then                                      -- If there is any solutions, then
        table.insert(solutions, table.concat(sol_pairs, ", "))    -- Save the sol_pairs
      end
    end

    -- g) If we found no solutions (e.g. the pattern didn't match), fallback
    ----------------------------------------------------------------------------
    if #solutions == 0 then                                 -- If no solution is found, then
      solutions = { variable .. " = " .. raw_result }       -- Print the raw_result
    end

    local solution_str = table.concat(solutions, ", ")      -- Formats the solutions into a string
    utils.debug_print("Final solution => " .. solution_str) -- (Optionally) prints the final solution-string

    -- h) Insert the solution below the selected lines
    ----------------------------------------------------------------------------
    vim.fn.append(end_row, solution_str)
  end)
end




-- 3) Append system solution asynchronously (multiple variables)
--------------------------------------------------------------------------------
function M.append_system_solution_async()

  -- a) Extract visual selection
  ------------------------------------------------------------------------------
  local start_row, start_col = vim.fn.line("'<"), vim.fn.col("'<")  -- Extracts the start of the visual selection
  local end_row,   end_col   = vim.fn.line("'>"), vim.fn.col("'>")  -- Extracts the end of the visual selection
  local lines                = vim.fn.getline(start_row, end_row)   -- lines is the rows in the visual selection

  lines[1]       = lines[1]:sub(start_col)                          -- Trim whitespace before visual selection
  lines[#lines]  = lines[#lines]:sub(1, end_col)                    -- Trim whitespace after visual selection
  local selection = table.concat(lines, "\n")                       -- Concatenates the selection into a single string with rows seperated by \n

  utils.debug_print("Original selection for sysem solve => " .. selection)  -- (Optionally) prints the original selection for the solve-command


  -- b) Split selection into individual equations
  ------------------------------------------------------------------------------
  local equations = utils.split_equations(selection)    -- Split the system of equations with split_equations
  if #equations < 2 then                                -- If less than two equations are selected, then
    vim.api.nvim_err_writeln("Error: Please select at least two equations for a system.") -- Print an error
    return
  end


  -- c) Preprocess each equation
  ------------------------------------------------------------------------------
  local preprocessed_equations = {}
  for i, eq in ipairs(equations) do                                     -- For each equation
    utils.debug_print("Preprocessing equations[" .. i .. "] => " .. eq) -- (Optionally) print the equations to be processed in a list
    preprocessed_equations[i] = utils.preprocess_equation(eq)           -- Call the preprocess_equation function on each equation
  end


  -- d) Check for balanced brackets
  ------------------------------------------------------------------------------
  for i, eq in ipairs(preprocessed_equations) do                                -- For each equation
    if not utils.is_balanced(eq) then                                           -- If is_balanced-check fails, then
      vim.api.nvim_err_writeln("Error: Unbalanced brackets in equation " .. i)  -- Print an error to the log
      return
    end
  end


  -- e) Replace single '=' => '=='
  ------------------------------------------------------------------------------
  local solve_equations = {}
  for i, eq in ipairs(preprocessed_equations) do            -- For each equation
    solve_equations[i] = eq:gsub("([^=])=([^=])", "%1==%2") -- Substitute = for ==
  end


  -- f) Extract variables from the preprocessed eqs
  ------------------------------------------------------------------------------
  local variables = utils.extract_variables(preprocessed_equations)                   -- Extract the variables using extract_variables
  if #variables == 0 then                                                             -- If no variables are found, then
    vim.api.nvim_err_writeln("Error: No variables found in the selected equations.")  -- Print an error to the log
    return
  end

  utils.debug_print("Preprocessed Equations for Solve => " .. table.concat(solve_equations, ", "))  -- (Optionally) print the preprocessed equations
  utils.debug_print("Variables => " .. table.concat(variables, ", "))                               -- (Optionally) print the variables to solve for


  -- g) Solve system of equations asynchronously
  ------------------------------------------------------------------------------
  async.run_solve_system_async(solve_equations, variables, function(raw_result, err)  -- Call the run_solve_system_async function 
    if err then                                   -- If an error occurs, then
      vim.api.nvim_err_writeln("Error: " .. err)  -- Write an error to the log
      return
    end
    if not raw_result or raw_result:find("$Failed") then                            -- If no solution is found, then
      vim.api.nvim_err_writeln("Error: Unable to solve the system of equations.")   -- Write an error to the log
      return
    end


    -- h) Unescape braces for correct parsing
    ----------------------------------------------------------------------------
    raw_result = raw_result:gsub("\\{", "{"):gsub("\\}", "}") -- Substitute escaped braces for unescaped braces


    -- i) Post-process result (same as for "single equation"-solve)
    ----------------------------------------------------------------------------
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


    -- j) If we found no solutions (e.g. the pattern didn't match), fallback (same as for "single equation"-solve)
    ----------------------------------------------------------------------------
    if #solutions == 0 then
      solutions = { "Solution: " .. raw_result }
    else
      for i, s in ipairs(solutions) do
        solutions[i] = "Solution " .. i .. ": " .. s
      end
    end

    local solution_str = table.concat(solutions, "\n")
    utils.debug_print("Final solution => " .. solution_str)


    -- k) Insert the solution below the selected lines (same as for "single equation"-solve)
    ----------------------------------------------------------------------------
    vim.fn.append(end_row, solution_str)
  end)
end




-- 4) Setup user commands
--------------------------------------------------------------------------------
function M.setup_commands()
  vim.api.nvim_create_user_command("TungstenSolve", function()
    M.append_solution_async()
  end, {
    range = true,
    desc = "Solve the selected equation for a specified variable. Usage: equation, variable"
  })

  vim.api.nvim_create_user_command("TungstenSolveSystem", function()
    M.append_system_solution_async()
  end, {
    range = true,
    desc = "Solve a system of selected equations."
  })
end

return M

