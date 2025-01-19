--------------------------------------------------------------------------------
-- taylor.lua
-- Handles Taylor-series functionality.
--------------------------------------------------------------------------------

-- 1) Serup
--------------------------------------------------------------------------------
local io_utils = require("tungsten.utils.io_utils").debug_print
local parser = require("tungsten.utils.parser")
local string_utils = require("tungsten.utils.string_utils")
local async = require("tungsten.async")

local M = {}


local function extract_taylor_spec(mainExpr)  -- Helper function that splits the mainExpr into a exprPart and a taylorSpec
  local last_open = mainExpr:match(".*()%[")  -- Extracts the last [
  local last_close = mainExpr:match("()%]")   -- Extracts the last ]

  if last_open and last_close and last_close > last_open then   -- If a last_open and last_close has been found whilst [ was before ], then
    local exprPart   = mainExpr:sub(1, last_open - 1):match("^%s*(.-)%s*$")               -- Set the expression part to be everything before the last [
    local taylorSpec = mainExpr:sub(last_open + 1, last_close - 1):match("^%s*(.-)%s*$")  -- Set taylorSpec to be everything inside the last []
    return exprPart, taylorSpec   -- Return the exprPart and the taylorSpec
  else
    return mainExpr, nil  -- If the checks for [] fails then just return the mainExpr
  end
end




-- 2) Insert Taylor-series function
--------------------------------------------------------------------------------
function M.insert_taylor_series()

  -- a) Extract visual selection
  ------------------------------------------------------------------------------
  local start_row, start_col = vim.fn.line("'<"), vim.fn.col("'<")  -- Extracts the start of the visual selection
  local end_row, end_col     = vim.fn.line("'>"), vim.fn.col("'>")  -- Extracts the end of the visual selection
  local lines                = vim.fn.getline(start_row, end_row)   -- lines is all rows in the visual selection

  lines[1]       = lines[1]:sub(start_col)        -- Trim whitespace before the selection
  lines[#lines]  = lines[#lines]:sub(1, end_col)  -- Trim whitespace after the selection
  local selection = table.concat(lines, "\n")     -- Concatenate the selection into a single string with rows seperated by \n

  io_utils("Taylor selection => " .. selection)  -- (Optionally) print the selection for the Taylor-series command


  -- b) Extract expression and taylor spec
  ------------------------------------------------------------------------------
  local exprPart, taylorSpec = extract_taylor_spec(selection)   -- Call the extract_taylor_spec-function
  if not taylorSpec then  -- If no taylorSpec is found, then
    vim.api.nvim_err_writeln("No [variable, expansion_point, order] found. Syntax: expr [var, point, order]") -- Print an error advising the user of syntax
    return
  end


  -- c) Preprocess the expression
  ------------------------------------------------------------------------------
  local preprocessed_expr = parser.preprocess_equation(exprPart) -- Call the Preprocess_equation-function


  -- d) Split taylorSpec by commas (variable, point of expansion, order)
  ------------------------------------------------------------------------------
  local parts = string_utils.split_by_comma(taylorSpec)  -- Call split_by_comma to split the specification at commas
  if #parts < 3 then  -- If less than 3 specifications are found, then
    vim.api.nvim_err_writeln("Taylor spec must have (var, expansion_point, order). Example: x, 0, 5")   -- Print an error to the log
    return
  end

  local var         = parts[1]:match("^%s*(.-)%s*$")  -- Set the first entry in parts as the variable whilst trimming whitespace
  local expansionPt = parts[2]:match("^%s*(.-)%s*$")  -- Set the second entry in parts as the expansion point whilst trimming whitespace
  local order       = parts[3]:match("^%s*(.-)%s*$")  -- Set the third entry in parts as the order of expansion whilst trimmming whitespace


  -- e) Build Wolfram Series code:
  ------------------------------------------------------------------------------
  local wolfram_code = string.format("ToString[Series[%s, {%s, %s, %s}], TeXForm]",
                                     preprocessed_expr, var, expansionPt, order)


  -- f) Run asynchronously
  ------------------------------------------------------------------------------
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

      local updated = selection .. " = " .. result  -- Stores the updated line to be inserted
      vim.fn.setline(start_row, updated)            -- Inserts the updated line into the buffer
      for i = start_row + 1, end_row do             -- Loops through all subsequent rows in the selection
        vim.fn.setline(i, "")                       -- Sets rows as empty strings
      end
    end
  )
end




-- 3) Setup user commandd
--------------------------------------------------------------------------------
function M.setup_commands()
  vim.api.nvim_create_user_command("TungstenTaylor", function()
    M.insert_taylor_series()
  end, {
    range = true,
    desc = "Compute Taylor series of an expression. Syntax: expr [var, point, order]"
  })
end

return M
