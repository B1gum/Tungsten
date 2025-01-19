--------------------------------------------------------------------------------
-- init.lua
-- Orchestrates the entire "plot from selection" workflow
--------------------------------------------------------------------------------

local extractors   = require("tungsten.utils.extractors")
local io_utils     = require("tungsten.utils.io_utils")
local parser       = require("tungsten.utils.parser")
local string_utils = require("tungsten.utils.string_utils")
local async        = require("tungsten.async")

local style        = require("tungsten.plot.style")
local cmdgen       = require("tungsten.plot.command")

local M = {}

function M.insert_plot_from_selection()
  io_utils.debug_print("insert_plot_from_selection START")

  -- Grab visual selection
  local start_row, start_col = vim.fn.line("'<"), vim.fn.col("'<")
  local end_row,   end_col   = vim.fn.line("'>"), vim.fn.col("'>")
  local lines               = vim.fn.getline(start_row, end_row)

  lines[1]       = lines[1]:sub(start_col)
  lines[#lines]  = lines[#lines]:sub(1, end_col)
  local selection = table.concat(lines, "\n")

  selection = selection:gsub("\194\160", " ") -- Replace non-breaking with normal spaces
  io_utils.debug_print("Plot selection => " .. selection)

  -- Extract main expression and curly spec
  local mainExpr, curlySpec = extractors.extract_main_and_curly(selection)
  if not mainExpr then
    mainExpr = selection
  end
  io_utils.debug_print("MainExpr => " .. (mainExpr or "nil"))
  io_utils.debug_print("CurlySpec => " .. (curlySpec or "nil"))

  local exprPart, rangeSpec = extractors.extract_expr_and_range(mainExpr)
  io_utils.debug_print("ExprPart => " .. (exprPart or "nil"))
  io_utils.debug_print("RangeSpec => " .. (rangeSpec or "nil"))

  -- Initialize
  local xlb, xub, ylb, yub, zlb, zub = nil, nil, nil, nil, nil, nil
  local plot_type = "2D"

  -- Parse range spec if present
  if exprPart and rangeSpec then
    local ranges = string_utils.split(rangeSpec, ";")
    if #ranges == 1 then
      local x_range = string_utils.split(ranges[1], ",")
      if #x_range ~= 2 then
        vim.api.nvim_err_writeln("Invalid range values for 2D plot. Use [x_min, x_max].")
        return
      end
      xlb, xub = x_range[1]:match("^%s*(.-)%s*$"), x_range[2]:match("^%s*(.-)%s*$")
      plot_type = "2D"
    elseif #ranges == 2 then
      local x_range = string_utils.split(ranges[1], ",")
      local y_range = string_utils.split(ranges[2], ",")
      if #x_range ~= 2 or #y_range ~= 2 then
        vim.api.nvim_err_writeln("Invalid range for 2D plot. [x_min, x_max; y_min, y_max].")
        return
      end
      xlb, xub = x_range[1]:match("^%s*(.-)%s*$"), x_range[2]:match("^%s*(.-)%s*$")
      ylb, yub = y_range[1]:match("^%s*(.-)%s*$"), y_range[2]:match("^%s*(.-)%s*$")
      plot_type = "2D"
    elseif #ranges == 3 then
      local x_range = string_utils.split(ranges[1], ",")
      local y_range = string_utils.split(ranges[2], ",")
      local z_range = string_utils.split(ranges[3], ",")
      if #x_range ~= 2 or #y_range ~= 2 or #z_range ~= 2 then
        vim.api.nvim_err_writeln("Invalid range values for 3D plot. [x_min, x_max; y_min, y_max; z_min, z_max].")
        return
      end
      xlb, xub = x_range[1]:match("^%s*(.-)%s*$"), x_range[2]:match("^%s*(.-)%s*$")
      ylb, yub = y_range[1]:match("^%s*(.-)%s*$"), y_range[2]:match("^%s*(.-)%s*$")
      zlb, zub = z_range[1]:match("^%s*(.-)%s*$"), z_range[2]:match("^%s*(.-)%s*$")
      plot_type = "3D"
    else
      vim.api.nvim_err_writeln("Invalid number of range specs.")
      return
    end
  else
    exprPart = mainExpr
    io_utils.debug_print("No rangeSpec found, ExprPart set to MainExpr")
  end

  -- Split & preprocess
  local exprList = string_utils.split_expressions(exprPart)
  io_utils.debug_print("ExprList => " .. table.concat(exprList, ", "))

  for i, expr in ipairs(exprList) do
    io_utils.debug_print("Preprocessing exprList[" .. i .. "] => " .. expr)
    -- Note: see fix for parser function call below
    exprList[i] = parser.preprocess_equation(expr) 
  end

  local finalExpr = string_utils.build_multi_expr(exprList)
  io_utils.debug_print("Final preprocessed expressions => " .. finalExpr)

  -- Possibly detect 3D if there's a 'y[...]' in the expression
  if plot_type == "2D" then
    for _, expr in ipairs(exprList) do
      if expr:find("y[%[%(%]]") then
        plot_type = "3D"
        io_utils.debug_print("Inferred 3D based on expression dependencies")
        break
      end
    end
  end

  -- If we ended up with 3D but no rangeSpec, you can handle defaults, etc.

  -- Build label list
  local labelList = {}
  for _, piece in ipairs(exprList) do
    local lbl = piece:gsub("^\\", ""):match("^%s*(.-)%s*$")
    table.insert(labelList, lbl)
  end

  -- Parse style options if curlySpec present
  local styleOpts = { hasLegend = false, directives = {} }
  if curlySpec then
    local parse_style = require("tungsten.plot.style").parse_plot_options
    styleOpts = parse_style(curlySpec, #exprList)
  end

  -- Generate filename
  local plotfile = io_utils.get_plot_filename()

  -- Generate plot command
  local plotCommand = cmdgen.generate_plot_command(
    finalExpr, plotfile,
    xlb, xub, ylb, yub, zlb, zub,
    styleOpts, labelList,
    plot_type
  )
  io_utils.debug_print("Wolfram Plot Command => " .. plotCommand)

  -- Actually run the plot (async)
  async.run_plot_async(plotCommand, plotfile, function(err)
    if err then
      vim.api.nvim_err_writeln("Plot error: " .. err)
      return
    end

    local include_line = "\\includegraphics[width=0.5\\textwidth]{" .. plotfile .. "}"
    io_utils.debug_print("Inserting => " .. include_line)
    vim.fn.append(end_row, include_line)
  end)
end

function M.setup_commands()
  vim.api.nvim_create_user_command("TungstenPlot", function()
    M.insert_plot_from_selection()
  end, { range = true })
end

return M

