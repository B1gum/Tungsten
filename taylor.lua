-- Handles Taylor-series functionality.

local utils = require("wolfram.utils")
local async = require("wolfram.async")

local M = {}

--------------------------------------------------------------------------------
-- Helper: extract_taylor_spec
--------------------------------------------------------------------------------
-- This function extracts (exprPart, taylorSpec) from the selection, where
-- taylorSpec is something like "x, 0, 5" = variable, expansion point, order.
--------------------------------------------------------------------------------
local function extract_taylor_spec(mainExpr)
  -- taylorSpec is found between the last [ and ] in the string
  local last_open = mainExpr:match(".*()%[")
  local last_close = mainExpr:match("()%]")

  if last_open and last_close and last_close > last_open then
    local exprPart   = mainExpr:sub(1, last_open - 1):match("^%s*(.-)%s*$")
    local taylorSpec = mainExpr:sub(last_open + 1, last_close - 1):match("^%s*(.-)%s*$")
    return exprPart, taylorSpec
  else
    return mainExpr, nil
  end
end

--------------------------------------------------------------------------------
-- insert_taylor_series
--------------------------------------------------------------------------------
-- 1) Grabs the selected text in visual mode
-- 2) Extracts the expression and [var, expansionPt, order]
-- 3) Preprocesses the expression (LaTeX => Wolfram)
-- 4) Builds the Wolfram command: Series[f(x), {x, x0, n}]
-- 5) Asynchronously executes
-- 6) Inserts result below the selection
--------------------------------------------------------------------------------
function M.insert_taylor_series()
  local start_row, start_col = vim.fn.line("'<"), vim.fn.col("'<")
  local end_row, end_col     = vim.fn.line("'>"), vim.fn.col("'>")
  local lines                = vim.fn.getline(start_row, end_row)

  lines[1]       = lines[1]:sub(start_col)
  lines[#lines]  = lines[#lines]:sub(1, end_col)
  local selection = table.concat(lines, "\n")

  utils.debug_print("Taylor selection => " .. selection)

  -- Extract expression and taylor spec
  local exprPart, taylorSpec = extract_taylor_spec(selection)
  if not taylorSpec then
    vim.api.nvim_err_writeln("No [variable, expansion_point, order] found. Syntax: expr [var, point, order]")
    return
  end

  -- Preprocess the expression
  local preprocessed_expr = utils.preprocess_equation(exprPart)

  -- Split taylorSpec by commas
  local parts = utils.split_by_comma(taylorSpec)
  if #parts < 3 then
    vim.api.nvim_err_writeln("Taylor spec must have (var, expansion_point, order). Example: x, 0, 5")
    return
  end

  local var         = parts[1]:match("^%s*(.-)%s*$")
  local expansionPt = parts[2]:match("^%s*(.-)%s*$")
  local order       = parts[3]:match("^%s*(.-)%s*$")

  -- Build Wolfram Series code:
  local wolfram_code = string.format("ToString[Series[%s, {%s, %s, %s}], TeXForm]",
                                     preprocessed_expr, var, expansionPt, order)

  -- Now run asynchronously
  async.run_wolframscript_async(
    { "wolframscript", "-code", wolfram_code, "-format", "OutputForm" },
    function(result, err)
      if err then
        vim.api.nvim_err_writeln("Error running Taylor series: " .. err)
        return
      end
      if not result or result:find("$Failed") then
        vim.api.nvim_err_writeln("Error: Wolfram failed to generate Taylor series.")
        return
      end

      local updated = selection .. " = " .. result
      vim.fn.setline(start_row, updated)
      for i = start_row + 1, end_row do
        vim.fn.setline(i, "")
      end
    end
  )
end

--------------------------------------------------------------------------------
-- Setup user command
--------------------------------------------------------------------------------
function M.setup_commands()
  vim.api.nvim_create_user_command("WolframTaylor", function()
    M.insert_taylor_series()
  end, {
    range = true,
    desc = "Compute Taylor series of an expression. Syntax: expr [var, point, order]"
  })
end

return M
