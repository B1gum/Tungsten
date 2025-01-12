-- Handles plot generation.

local utils = require("tungsten.utils")
local async = require("tungsten.async")

local M = {}

-- Define a list of custom hex colors
local defaultColors = { "#FFA4E9", "#2C9C38", "#F0A830", "#0B486B", "#E3DAC9", "#272941", "#318CE7", "#1CCEB7", "#008080", "#1B4D3E", "#841B2D", "#7b1E7A", "#E95081", "#000000" }
local defaultColorIndex = 1

-- Convert hex to RGBColor in Wolfram syntax
local function hex_to_rgbcolor(hex)
  local r, g, b = hex:match("^#(%x%x)(%x%x)(%x%x)$")
  r, g, b = tonumber(r, 16) / 255, tonumber(g, 16) / 255, tonumber(b, 16) / 255
  return string.format("RGBColor[%f, %f, %f]", r, g, b)
end

-- Function to get the next default color
local function get_next_default_color()
  local color = defaultColors[defaultColorIndex]
  defaultColorIndex = defaultColorIndex + 1
  if defaultColorIndex > #defaultColors then
    defaultColorIndex = 1 -- cycle back to the first color
  end
  return hex_to_rgbcolor(color)
end

-- Recognized colors; add more as needed
local knownColors = { red=true, blue=true, green=true, black=true, brown=true, gray=true, orange=true, purple=true, yellow=true, cyan=true, magenta=true }

-- Parse plot options
local function parse_plot_options(curlyString, numExprs)
  -- Returns { hasLegend = boolean, directives = { "Directive[...]", "Automatic", ... } }
  local tokens = {}
  for piece in curlyString:gmatch("[^,]+") do
    local trimmed = piece:gsub("^%s+", ""):gsub("%s+$", "")
    table.insert(tokens, trimmed)
  end

  local hasLegend = false

  -- Tables to store style directives
  local colorFor = {}
  local thickFor = {}
  local styleFor = {}

  -- Indices to track assignments
  local colorIndex, thickIndex, styleIndex = 1, 1, 1

  for _, token in ipairs(tokens) do
    local lowerTok = token:lower()

    if lowerTok == "legend" then
      hasLegend = true

    else
      -- Check for color with style, e.g., "red--" or "blue-"
      local colorPart, dashPart = token:match("^(%a+)(%-+)$")  -- e.g., "blue--" => colorPart="blue", dashPart="--"
      if colorPart and dashPart then
        if knownColors[colorPart:lower()] then
          -- Assign color
          if colorIndex <= numExprs then
            colorFor[colorIndex] = colorPart
            colorIndex = colorIndex + 1
          end
        end

        -- Assign style
        if styleIndex <= numExprs then
          styleFor[styleIndex] = (dashPart == "--") and "Dashed" or "Solid"
          styleIndex = styleIndex + 1
        end

      else
        -- Pure color without style
        if knownColors[lowerTok] then
          if colorIndex <= numExprs then
            colorFor[colorIndex] = lowerTok
            colorIndex = colorIndex + 1
          end

        -- Pure style without color, e.g., "--" or "-"
        elseif token:match("^%-+$") then
          if styleIndex <= numExprs then
            styleFor[styleIndex] = (token == "--") and "Dashed" or "Solid"
            styleIndex = styleIndex + 1
          end

        -- Thickness (number)
        elseif tonumber(token) then
          if thickIndex <= numExprs then
            thickFor[thickIndex] = tonumber(token) * 0.003  -- Scale thickness as needed
            thickIndex = thickIndex + 1
          end

        else
          -- Unknown token; ignore or handle as needed
        end
      end
    end
  end

  -- Assign colors from defaultColors for any 'Automatic' entries
  for i = 1, numExprs do
    if not colorFor[i] then
      colorFor[i] = get_next_default_color()
    else
      -- Convert color names to Wolfram's RGBColor or known color names
      local colorName = colorFor[i]:lower()
      if knownColors[colorName] then
        colorFor[i] = colorName:sub(1,1):upper() .. colorName:sub(2)
      else
        colorFor[i] = get_next_default_color()
      end
    end
  end

  -- Assign PlotStyle directives, mixing user-specified and Automatic
  local directives = {}
  for i = 1, numExprs do
    local parts = {}

    -- Thickness
    if thickFor[i] then
      table.insert(parts, string.format("Thickness[%f]", thickFor[i]))
    end

    -- Color (explicitly assigned)
    if colorFor[i] then
      table.insert(parts, colorFor[i])
    end

    -- Style
    if styleFor[i] then
      table.insert(parts, styleFor[i])
    end

    if colorFor[i] or styleFor[i] or thickFor[i] then
      table.insert(directives, "Directive[" .. table.concat(parts, ", ") .. "]")
    else
      table.insert(directives, "Automatic")
    end
  end

  return {
    hasLegend = hasLegend,
    directives = directives
  }
end

-- Generate the Wolfram plot command based on parameters
local function generate_plot_command(expr, plotfile, xlb, xub, ylb, yub, zlb, zub, styleOpts, labels, plot_type)
  local plotCommand = ""

  if plot_type == "2D" then
    -- Handle 2D PlotRange
    local plotRange = ""
    if ylb and yub then
      plotRange = string.format("PlotRange -> {{%s, %s}, {%s, %s}}", xlb, xub, ylb, yub)
    else
      plotRange = string.format("PlotRange -> {{%s, %s}, Automatic}", xlb, xub)
    end

    -- Handle PlotLegends
    local plotLegends = ""
    if styleOpts.hasLegend then
      if #labels > 0 then
        local styleListStr = "{" .. table.concat(styleOpts.directives, ", ") .. "}"
        local labelListStr = "{" .. table.concat(vim.tbl_map(function(label)
          return string.format("\"%s\"", label)
        end, labels), ", ") .. "}"
        plotLegends = string.format("PlotLegends -> LineLegend[%s, %s]", styleListStr, labelListStr)
      else
        plotLegends = "PlotLegends -> Automatic"
      end
    end

    -- Handle PlotStyle
    local plotStyle = (#styleOpts.directives > 0) and "PlotStyle -> {" .. table.concat(styleOpts.directives, ", ") .. "}" or "PlotStyle -> Automatic"

    -- Construct the Plot command
    plotCommand = string.format("Plot[%s, {x, %s, %s}, %s, %s%s]",
      expr, xlb, xub, plotStyle, plotRange,
      (plotLegends ~= "" and (", " .. plotLegends) or "")
    )
  elseif plot_type == "3D" then
    -- Handle 3D PlotRange
    local plotRange = ""
    if ylb and yub and zlb and zub then
      plotRange = string.format("PlotRange -> {{%s, %s}, {%s, %s}, {%s, %s}}", xlb, xub, ylb, yub, zlb, zub)
    elseif ylb and yub then
      plotRange = string.format("PlotRange -> {{%s, %s}, {%s, %s}, Automatic}", xlb, xub, ylb, yub)
    else
      plotRange = string.format("PlotRange -> {{%s, %s}, Automatic, Automatic}", xlb, xub)
    end

    -- Handle PlotLegends
    local plotLegends = ""
    if styleOpts.hasLegend then
      if #labels > 0 then
        local styleListStr = "{" .. table.concat(styleOpts.directives, ", ") .. "}"
        local labelListStr = "{" .. table.concat(vim.tbl_map(function(label)
          return string.format("\"%s\"", label)
        end, labels), ", ") .. "}"
        plotLegends = string.format("PlotLegends -> LineLegend[%s, %s]", styleListStr, labelListStr)
      else
        plotLegends = "PlotLegends -> Automatic"
      end
    end

    -- Handle PlotStyle
    local plotStyle = (#styleOpts.directives > 0) and "PlotStyle -> {" .. table.concat(styleOpts.directives, ", ") .. "}" or "PlotStyle -> Automatic"

    -- Construct the Plot3D command
    plotCommand = string.format("Plot3D[%s, {x, %s, %s}, {y, %s, %s}, %s, %s%s]",
      expr, xlb, xub, ylb, yub, plotStyle, plotRange,
      (plotLegends ~= "" and (", " .. plotLegends) or "")
    )
  else
    error("Unknown plot type: " .. plot_type)
  end

  return plotCommand
end

-- Insert plot from selection with enhanced range parsing
function M.insert_plot_from_selection()
  utils.debug_print("insert_plot_from_selection START")

  local start_row, start_col = vim.fn.line("'<"), vim.fn.col("'<")
  local end_row, end_col     = vim.fn.line("'>"), vim.fn.col("'>")
  local lines                = vim.fn.getline(start_row, end_row)

  -- Adjust the first and last lines based on column selection
  lines[1]    = lines[1]:sub(start_col)
  lines[#lines] = lines[#lines]:sub(1, end_col)
  local selection = table.concat(lines, "\n")

  -- Normalize the selection by replacing non-breaking spaces with regular spaces
  selection = selection:gsub("\194\160", " ")

  utils.debug_print("Plot selection => " .. selection)

  -- Extract optional { ... } for style tokens
  local mainExpr, curlySpec = utils.extract_main_and_curly(selection)
  if not mainExpr then
    mainExpr = selection
  end
  utils.debug_print("MainExpr => " .. (mainExpr or "nil"))
  utils.debug_print("CurlySpec => " .. (curlySpec or "nil"))

  -- Extract exprPart and rangeSpec from mainExpr
  local exprPart, rangeSpec = utils.extract_expr_and_range(mainExpr)
  utils.debug_print("ExprPart => " .. (exprPart or "nil"))
  utils.debug_print("RangeSpec => " .. (rangeSpec or "nil"))

  local xlb, xub, ylb, yub, zlb, zub = "-2", "2", nil, nil, nil, nil
  local plot_type = "2D"  -- Default to 2D

  if exprPart and rangeSpec then
    -- Split ranges by semicolon
    local ranges = utils.split(exprPart, ";")
    if #ranges == 1 then
      -- 2D plot with only x-range
      local x_range = utils.split(ranges[1], ",")
      if #x_range ~=2 then
        vim.api.nvim_err_writeln("Invalid range values for 2D plot. Use [x_min, x_max].")
        return
      end
      xlb, xub = x_range[1]:match("^%s*(.-)%s*$"), x_range[2]:match("^%s*(.-)%s*$")
      -- ylb, yub remain nil (Automatic)
      plot_type = "2D"
      utils.debug_print("Detected 1 range: 2D plot with y-range=Automatic")
    elseif #ranges == 2 then
      -- 2D plot with x and y ranges
      local x_range = utils.split(ranges[1], ",")
      local y_range = utils.split(ranges[2], ",")
      if #x_range ~= 2 or #y_range ~=2 then
        vim.api.nvim_err_writeln("Invalid range values for 2D plot. Use [x_min, x_max; y_min, y_max].")
        return
      end
      xlb, xub = x_range[1]:match("^%s*(.-)%s*$"), x_range[2]:match("^%s*(.-)%s*$")
      ylb, yub = y_range[1]:match("^%s*(.-)%s*$"), y_range[2]:match("^%s*(.-)%s*$")
      plot_type = "2D"
      utils.debug_print("Detected 2 ranges: 2D plot with specified y-range")
    elseif #ranges ==3 then
      -- 3D plot with x, y, z ranges
      local x_range = utils.split(ranges[1], ",")
      local y_range = utils.split(ranges[2], ",")
      local z_range = utils.split(ranges[3], ",")
      if #x_range ~=2 or #y_range ~=2 or #z_range ~=2 then
        vim.api.nvim_err_writeln("Invalid range values for 3D plot. Use [x_min, x_max; y_min, y_max; z_min, z_max].")
        return
      end
      xlb, xub = x_range[1]:match("^%s*(.-)%s*$"), x_range[2]:match("^%s*(.-)%s*$")
      ylb, yub = y_range[1]:match("^%s*(.-)%s*$"), y_range[2]:match("^%s*(.-)%s*$")
      zlb, zub = z_range[1]:match("^%s*(.-)%s*$"), z_range[2]:match("^%s*(.-)%s*$")
      plot_type = "3D"
      utils.debug_print("Detected 3 ranges: 3D plot with specified z-range")
    else
      vim.api.nvim_err_writeln("Invalid number of range specifications. Use [x_min, x_max], [x_min, x_max; y_min, y_max], or [x_min, x_max; y_min, y_max; z_min, z_max].")
      return
    end
  else
    exprPart = mainExpr
    utils.debug_print("No rangeSpec found, ExprPart set to MainExpr")
  end

  -- Split expressions
  local exprList = utils.split_expressions(exprPart)
  utils.debug_print("ExprList => " .. table.concat(exprList, ", "))

  -- Preprocess each expression
  for i, expr in ipairs(exprList) do
    utils.debug_print("Preprocessing exprList[" .. i .. "] => " .. expr)
    exprList[i] = utils.preprocess_equation(expr)
  end

  local finalExpr = utils.build_multi_expr(exprList)
  utils.debug_print("Final preprocessed expressions => " .. finalExpr)

  -- Determine plot type based on expressions (if not already determined)
  if plot_type == "2D" then
    -- Check if any expression depends on 'y'
    for _, expr in ipairs(exprList) do
      if expr:find("y[%[%(%]]") then  -- Simple check for presence of 'y'
        plot_type = "3D"
        utils.debug_print("Inferred plot type as 3D based on expression dependencies")
        break
      end
    end
  end

  -- After potentially updating plot_type, parse ranges again if needed
  if plot_type == "3D" then
    if exprPart:match("y[%[%(%]]") then
      -- If plot_type changed to 3D, adjust PlotRange accordingly
      if not rangeSpec then
        -- No ranges provided; default to Automatic
        xlb, xub, ylb, yub, zlb, zub = "-2", "2", nil, nil, nil, nil
      else
        -- Ranges have already been parsed above
        -- Ensure that unspecified ranges are set to Automatic
        local ranges = utils.split(rangeSpec, ";")
        if #ranges ==1 then
          -- [x_min, x_max], y and z set to Automatic
          ylb, yub, zlb, zub = nil, nil, nil, nil
        elseif #ranges ==2 then
          -- [x_min, x_max; y_min, y_max], z set to Automatic
          zlb, zub = nil, nil
        end
      end
    end
  end

  -- Capture labels by stripping leading backslashes and trimming
  local labelList = {}
  for _, piece in ipairs(exprList) do
    local label = piece:gsub("^\\", ""):match("^%s*(.-)%s*$")
    table.insert(labelList, label)
  end

  -- Parse style options if curlySpec was found
  local styleOpts = { hasLegend = false, directives = {} }
  if curlySpec then
    styleOpts = require("tungsten.plot").parse_plot_options(curlySpec, #exprList)
  end

  -- Generate plot filename
  local plotfile = utils.get_plot_filename()

  -- Generate the Wolfram plot command
  local plotCommand = generate_plot_command(finalExpr, plotfile, xlb, xub, ylb, yub, zlb, zub, styleOpts, labelList, plot_type)
  utils.debug_print("Wolfram Plot Command => " .. plotCommand)

  -- Run plot asynchronously
  async.run_plot_async(plotCommand, plotfile, function(err)
    if err then
      vim.api.nvim_err_writeln("Plot error: " .. err)
      return
    end

    local include_line = "\\includegraphics[width=0.5\\textwidth]{" .. plotfile .. "}"
    utils.debug_print("Inserting => " .. include_line)
    vim.fn.append(end_row, include_line)
  end)
end

-- Create user command for plot
function M.setup_commands()
  vim.api.nvim_create_user_command("WolframPlot", function()
    M.insert_plot_from_selection()
  end, { range = true })
end

return M
