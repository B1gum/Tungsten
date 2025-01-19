---------------------------------------------------------------------------------
-- plot.lua
-- Handles plot generation
--------------------------------------------------------------------------------- 

-- 1) Setup
---------------------------------------------------------------------------------
local extractors = require("tungsten.utils.extractors")
local io_utils = require("tungsten.utils.io_utils")
local parser = require("tungsten.utils.parser")
local string_utils = require("tungsten.utils.string_utils")
local async = require("tungsten.async")

local M = {}




-- 2) Colors
---------------------------------------------------------------------------------
-- Define a list of custom hex colors
local defaultColors = { "#FFA4E9", "#2C9C38", "#F0A830", "#0B486B", "#E3DAC9", "#272941", "#318CE7", "#1CCEB7", "#008080", "#1B4D3E", "#841B2D", "#7b1E7A", "#E95081", "#000000" }
local defaultColorIndex = 1 -- Set color-index to 1

-- Convert hex to RGBColor in Wolfram syntax
local function hex_to_rgbcolor(hex)
  local r, g, b = hex:match("^#(%x%x)(%x%x)(%x%x)$")                            -- Matches the (r)ed, (g)reen, and (b)lue components from the hex string
  r, g, b = tonumber(r, 16) / 255, tonumber(g, 16) / 255, tonumber(b, 16) / 255 -- Converts from "hexadecimal" to "0 to 1"-style RGB
  return string.format("RGBColor[%f, %f, %f]", r, g, b)                         -- Returns the string in Wolframs RGBColor-format
end

-- Function to get the next default color
local function get_next_default_color()
  local color = defaultColors[defaultColorIndex]  -- Sets the color to the entry in defaultColors that matches the defaultColorIndex
  defaultColorIndex = defaultColorIndex + 1       -- Increments defaultColorIndex
  if defaultColorIndex > #defaultColors then      -- If defaultColorIndex is larger than the amount of items in defaultColors then
    defaultColorIndex = 1                         -- cycle back to the first color
  end
  return hex_to_rgbcolor(color)                   -- Returns an RGBColor-formatted color-value
end

-- Sets recognized colors; add more as needed
local knownColors = { red=true, blue=true, green=true, black=true, brown=true, gray=true, orange=true, purple=true, yellow=true, cyan=true, magenta=true }




-- 3) Parse plot options
---------------------------------------------------------------------------------
local function parse_plot_options(curlyString, numExprs)    -- curlyString is plot-options and numExprs is the number of expressions to be plotted
                                                            -- Returns { hasLegend = boolean, directives = { "Directive[...]", "Automatic", ... } }
  local tokens = {}
  for piece in curlyString:gmatch("[^,]+") do               -- Split the expression in the plot-options into tokens by commas
    local trimmed = piece:gsub("^%s+", ""):gsub("%s+$", "") -- Trim the tokens by removing whitespace
    table.insert(tokens, trimmed)                           -- Stores all trimmed tokens for further processing
  end

  local hasLegend = false -- Sets default for whether or not there should be a legend

  -- Tables to store style directives
  local colorFor = {} -- Stores color-settings for each expression
  local thickFor = {} -- Stores thickness-settings for each expression
  local styleFor = {} -- Stoes style-settings for each expression

  -- Initialize indices to keep track of assignments in the different tables
  local colorIndex, thickIndex, styleIndex = 1, 1, 1

  for _, token in ipairs(tokens) do -- Iterates over all tokens
    local lowerTok = token:lower()  -- Converts all tokens to lower-case

    if lowerTok == "legend" then    -- If any token is the string "legend" then set hasLegend = true
      hasLegend = true

    else
      -- Check for color with style, e.g., "red--" or "blue-"
      local colorPart, dashPart = token:match("^(%a+)(%-+)$")   -- Matches colorPart with letters and dashPart of dashes (specifies linestyle)
      if colorPart and dashPart then                            -- Checks if both a color-spec and a line-style-spec has been given
        if knownColors[colorPart:lower()] then                  -- If the given color matches an entry in knownColors then
          if colorIndex <= numExprs then                        -- Checks if there are anymore expressions that need to get a color set
            colorFor[colorIndex] = colorPart                    -- Sets color based on colorIndex
            colorIndex = colorIndex + 1                         -- Increments the colorIndex
          end
        end

        -- Assign style
        if styleIndex <= numExprs then                                        -- Checks if there are anymore expressions that need to get a style set
          styleFor[styleIndex] = (dashPart == "--") and "Dashed" or "Solid"   -- Assigns Dashed if dashPart is -- and solid if dashPart is anything else
          styleIndex = styleIndex + 1                                         -- Increments the styleIndex
        end

      else
        -- Pure color without style
        if knownColors[lowerTok] then         -- If the token matches an entry in knownColors then
          if colorIndex <= numExprs then      -- Checks if there are anymore expressions that need to get a color set
            colorFor[colorIndex] = lowerTok   -- Sets the color based on colorIndex
            colorIndex = colorIndex + 1       -- Increments the colorIndex
          end

        -- Pure style without color, e.g., "--" or "-"
        elseif token:match("^%-+$") then                                    -- Checks if the token is just a style-spec
          if styleIndex <= numExprs then                                    -- Checks if there are anymore expressions that need to get a style set
            styleFor[styleIndex] = (token == "--") and "Dashed" or "Solid"  -- Assigns Dashed if the entire token is just "--" and solid if it is anything else
            styleIndex = styleIndex + 1                                     -- Increments the styleIndex
          end

        -- Thickness (number)
        elseif tonumber(token) then                         -- If the token is a number then
          if thickIndex <= numExprs then                    -- Checks if there are anymore expressions that need to get a thickness set
            thickFor[thickIndex] = tonumber(token) * 0.005  -- Scale thickness
            thickIndex = thickIndex + 1                     -- Increments the thickIndex
          end
        end
      end
    end
  end

  -- Assign colors from defaultColors for any 'Automatic' entries
  for i = 1, numExprs do                      -- Loop through all the expressions
    if not colorFor[i] then                   -- For all expressions not having a color
      colorFor[i] = get_next_default_color()  -- Set a color using get_next_default_color
    else
      -- Convert color names to Wolfram's RGBColor or known color names
      local colorName = colorFor[i]:lower()                           -- Extracts the colorNames
      if knownColors[colorName] then                                  -- If the colorName matches a known color then
        colorFor[i] = colorName:sub(1,1):upper() .. colorName:sub(2)  -- Format the colorName
      else
        colorFor[i] = get_next_default_color()                        -- Else assign a random color using get_next_default_color
      end
    end
  end

  -- Transform plotstyling into directive-style specifications for Wolfram
  local directives = {}
  for i = 1, numExprs do    -- Iterates through all expressions
    local parts = {}

    -- Thickness
    if thickFor[i] then                                                 -- If a thickness is specifiec, then
      table.insert(parts, string.format("Thickness[%f]", thickFor[i]))  -- Add Thickness[value]
    end

    -- Color (explicitly assigned)
    if colorFor[i] then                 -- If a color is specified, then
      table.insert(parts, colorFor[i])  -- Add a color-specification to the directive
    end

    -- Style
    if styleFor[i] then                 -- If a style is specified, then
      table.insert(parts, styleFor[i])  -- Add a style-specification to the directive
    end

    if colorFor[i] or styleFor[i] or thickFor[i] then                             -- If any style components are present, then
      table.insert(directives, "Directive[" .. table.concat(parts, ", ") .. "]")  -- Combine the style components into a style-directive for Wolfram
    else
      table.insert(directives, "Automatic")                                       -- Else set the style-directive to "Automatic"
    end
  end

  return {                    -- Return-value is a directive containing
    hasLegend = hasLegend,    -- whether or not a legend should be included
    directives = directives   -- and the style-directive
  }
end




-- 4) Generate the Wolfram plot command
---------------------------------------------------------------------------------
local function generate_plot_command(expr, plotfile, xlb, xub, ylb, yub, zlb, zub, styleOpts, labels, plot_type)
  -- Function parameters:
    -- expr: The mathematical expression(s) to plot
    -- plotfile: The filename to which the plot should be saved
    -- xlb, xub: The lower and upper bounds for the x-axis
    -- ylb, yub: The lower and upper bounds for the y-axis
    -- zlb, zub: The lower and upper bounds for the z-axis
    -- styleOpts: A table containing a style-directive and whether or not a legend should be included
    -- labels: Labels for the plotted expressions
    -- plot_type: Type of plot (2D or 3D)


  local plotCommand = ""

  -- a) Determine the variable range specification
  -----------------------------------------------------------------------------
  local varRange = ""
  if xlb and xub then                                                               -- If an x-range has been given, then
    varRange = string.format("{x, %s, %s}", xlb, xub)                               -- Store that range
  else
    varRangeX = "{x, -10, 10}"                                                      -- Else, sets a default x-range of -10 to 10
    io_utils.debug_print("No x-rangeSpec found, using default range: " .. varRange)    -- (Optionally) print that no x-range was found and a default was chosen
  end

  if plot_type == "3D" then                                                         -- If plot is 3D
    if ylb and yub then                                                             -- If a y-range has been given, then
      varRangeY = string.format("{y, %s, %s}", ylb, yub)                            -- Store the y-range
    else
      varRangeY = "{y, -10, 10}"                                                    -- Else, sets a default y-range of -10 to 10
      io_utils.debug_print("No y-rangeSpec found, using default range: " .. varRangeY) -- (Optionally) print that no y-range was found and a default was chosen
    end
  end

  -- b) 2D-plots
  -----------------------------------------------------------------------------
  if plot_type == "2D" then   -- Checks if the plot should be a 2D-plot

    -- 1. Handle 2D PlotRange
    ---------------------------------------------------------------------------
    local plotRange = ""
    if ylb and yub then                                                                   -- If y-ranges have been specified, then
      plotRange = string.format("PlotRange -> {{%s, %s}, {%s, %s}}", xlb, xub, ylb, yub)  -- Set PlotRange to the given ranges
    else                                                                                  -- Else 
      plotRange = string.format("PlotRange -> {{%s, %s}, Automatic}", xlb, xub)           -- Set PlotRange to the given range for the x-coordinate and "Automatic" for the y-coordinate
    end

    -- 2. Handle PlotLegends
    ---------------------------------------------------------------------------
    local plotLegends = ""
    if styleOpts.hasLegend then                                                                       -- If a legend is wanted
      if #labels > 0 then                                                                             -- If labels have been provided
        local styleListStr = "{" .. table.concat(styleOpts.directives, ", ") .. "}"                   -- Construct style-string LineLegend
        local labelListStr = "{" .. table.concat(vim.tbl_map(function(label)                          -- Construct label-string for LineLegend
          return string.format("\"%s\"", label)
        end, labels), ", ") .. "}"
        plotLegends = string.format("PlotLegends -> LineLegend[%s, %s]", styleListStr, labelListStr)  -- Put style-string and label-string into LineLegend
      else
        plotLegends = "PlotLegends -> Automatic"                                                      -- Else set the legend-style to Automatic
      end
    end

    -- 3. Handle PlotStyle
    ---------------------------------------------------------------------------
    local plotStyle = (#styleOpts.directives > 0) and "PlotStyle -> {" .. table.concat(styleOpts.directives, ", ") .. "}" or "PlotStyle -> Automatic"   -- If style directives are present then format them as "PlotStyle -> {Directive[...]}", otherwise defaults to automatic

    -- 4. Construct the Plot command
    ---------------------------------------------------------------------------
    plotCommand = string.format("Plot[%s, %s, %s, %s%s]", expr, varRangeX , plotStyle, plotRange,     -- Construct the plot-command
        (plotLegends ~= "" and (", " .. plotLegends) or ""))


  -- c) 3D-plots
  -----------------------------------------------------------------------------
  elseif plot_type == "3D" then   -- Checks if plot_type is 3D

    -- 1. Handle 3D PlotRange
    ---------------------------------------------------------------------------
    local plotRange = ""
    if xlb and xub and ylb and yub and zlb and zub then                                                       -- If both x-range, y-range and z-range has been given, then
      plotRange = string.format("PlotRange -> {{%s, %s}, {%s, %s}, {%s, %s}}", xlb, xub, ylb, yub, zlb, zub)  -- set PlotRange to the given ranges.
    elseif xlb and xub and ylb and yub then                                                                   -- If only x-range and y-range have been given, then
      plotRange = string.format("PlotRange -> {{%s, %s}, {%s, %s}, Automatic}", xlb, xub, ylb, yub)           -- set PlotRange to the given ranges for the x- and y-coordinates and automatic for z.
    else                                                                                                      -- Else
      plotRange = string.format("PlotRange -> {{%s, %s}, Automatic, Automatic}", xlb, xub)                    -- Set PlotRange to the given range for the x-coordinate and automatic for y and z.
    end

    -- 2. Handle PlotLegends
    ---------------------------------------------------------------------------
    local plotLegends = ""
    if styleOpts.hasLegend then                                                                       -- Checks if a legend should be made
      if #labels > 0 then                                                                             -- If labels have been specified then make LineLegend similar to the 2D-functionality
        local styleListStr = "{" .. table.concat(styleOpts.directives, ", ") .. "}"
        local labelListStr = "{" .. table.concat(vim.tbl_map(function(label)
          return string.format("\"%s\"", label)
        end, labels), ", ") .. "}"
        plotLegends = string.format("PlotLegends -> LineLegend[%s, %s]", styleListStr, labelListStr)
      else
        plotLegends = "PlotLegends -> Automatic"                                                      -- Else set plotLegends to automatic
      end
    end

    -- 3. Handle PlotStyle
    ---------------------------------------------------------------------------
    local plotStyle = (#styleOpts.directives > 0) and "PlotStyle -> {" .. table.concat(styleOpts.directives, ", ") .. "}" or "PlotStyle -> Automatic"   -- Formats style-directives or defaults to automatic

    -- 4. Construct the Plot3D command
    ---------------------------------------------------------------------------
    plotCommand = string.format("Plot3D[%s, %s, %s, %s, %s%s]",   -- Constructs plot-command by concatenating strings the same way as for the 2D-functionality
      expr, varRangeX, varRangeY, plotStyle, plotRange,
      (plotLegends ~= "" and (", " .. plotLegends) or "")
    )
  else
    error("Unknown plot type: " .. plot_type)   -- Prints an error if the plot_type is neither 2D or 3D
  end

  io_utils.debug_print("Generated Plot Command: " .. plotCommand)    -- (Optionally print the generated plot-command

  return plotCommand    -- Returns the plotCommand
end




-- 5) Insert plot from selection 
---------------------------------------------------------------------------------
function M.insert_plot_from_selection()
  io_utils.debug_print("insert_plot_from_selection START")   -- Logs the start of insert_plot_from_selection for Debugging purposes


  -- a) Capturing the visual selection range
  -------------------------------------------------------------------------------
  local start_row, start_col = vim.fn.line("'<"), vim.fn.col("'<")  -- Extracts the start of the visual selection
  local end_row, end_col     = vim.fn.line("'>"), vim.fn.col("'>")  -- Extracts the end of the visual selection
  local lines                = vim.fn.getline(start_row, end_row)   -- lines is the rows from the visual selection 

  -- Trim the lines from the visual selection
  lines[1]    = lines[1]:sub(start_col)
  lines[#lines] = lines[#lines]:sub(1, end_col)
  local selection = table.concat(lines, "\n")

  selection = selection:gsub("\194\160", " ")           -- Normalize the selection by replacing non-breaking whitespace-characters with normal space

  io_utils.debug_print("Plot selection => " .. selection)  -- (Optionally) prints the normalized plot selection


  -- b) Parse the selection
  -------------------------------------------------------------------------------
  -- Extract the CurlySpec (style-spec)
  local mainExpr, curlySpec = extractors.extract_main_and_curly(selection)   -- Seperates the main-expression to be plotted from the style specification ( enclosed within {} )
  if not mainExpr then                                                  -- Fallback: If no mainExpr is found bu extract_main_and_curly, them
    mainExpr = selection                                                -- set the entire selection as the mainExpr
  end
  io_utils.debug_print("MainExpr => " .. (mainExpr or "nil"))              -- (Optionally) prints the MainExpr (Expression to be plotted)
  io_utils.debug_print("CurlySpec => " .. (curlySpec or "nil"))            -- (Optionally) prints the CurlySpec (Style-spec)

  -- Extract the exprPart (expression to be plotted) and rangeSpec (range to plot within) from mainExpr
  local exprPart, rangeSpec = utils.extract_expr_and_range(mainExpr)    -- Seperated the exprPart from the rangeSpec
  io_utils.debug_print("ExprPart => " .. (exprPart or "nil"))              -- (Optionally) prints the expression to be plotted
  io_utils.debug_print("RangeSpec => " .. (rangeSpec or "nil"))            -- (Optionally) prints the range to plot within

  local xlb, xub, ylb, yub, zlb, zub = nil, nil, nil, nil, nil, nil     -- Sets range-variables to nil for automatic range-handling if no range is given
  local plot_type = "2D"                                                -- Default to 2D

  -- c) Parse rangeSpec
  -------------------------------------------------------------------------------
  if exprPart and rangeSpec then                    -- If both an expression and a range has been given, then
    local ranges = string_utils.split(rangeSpec, ";")      -- Split the given range by semi-colons
    if #ranges == 0 then                            -- If no range has been given, then do nothing as the default plotRange is automatic
      -- 2D plot with automatic range

    elseif #ranges == 1 then                        -- If only one range has been given, then
      -- 2D plot with only x-range
      local x_range = string_utils.split(ranges[1], ",")   -- Split set the range at a comma
      if #x_range ~=2 then                          -- If the amount of values given for x_range is not exactly 2, then
        vim.api.nvim_err_writeln("Invalid range values for 2D plot. Use [x_min, x_max].")   -- Write an error to the log
        return
      end
      xlb, xub = x_range[1]:match("^%s*(.-)%s*$"), x_range[2]:match("^%s*(.-)%s*$")   -- Set the lower bound (xlb) to the first value in the list and vice versa
      -- ylb, yub remain nil (Automatic)
      plot_type = "2D"
      io_utils.debug_print("Detected 1 range: 2D plot with y-range=Automatic")           -- (Optionally) print the detected amount of ranges

    elseif #ranges == 2 then                        -- If two ranges have been given
      -- 2D plot with x and y ranges
      local x_range = string_utils.split(ranges[1], ",")   -- Split the x_range at a comma
      local y_range = string_utils.split(ranges[2], ",")   -- Split the y_range at a comma
      if #x_range ~= 2 or #y_range ~=2 then         -- If there is not exactly two entries in both x_range and y_range, then
        vim.api.nvim_err_writeln("Invalid range values for 2D plot. Use [x_min, x_max; y_min, y_max].")   -- Write an error to the log
        return
      end
      xlb, xub = x_range[1]:match("^%s*(.-)%s*$"), x_range[2]:match("^%s*(.-)%s*$")   -- Set the lower bound (xlb) to the first value in the x_range-list and vice versa
      ylb, yub = y_range[1]:match("^%s*(.-)%s*$"), y_range[2]:match("^%s*(.-)%s*$")   -- Set the lower bound (ylb) to the first value in the y_range-list and vice versa
      plot_type = "2D"
      io_utils.debug_print("Detected 2 ranges: 2D plot with specified y-range")          -- (Optionally) print the detected amount of ranges

    elseif #ranges ==3 then                                   -- If three ranges have been given
      -- 3D plot with x, y, z ranges
      local x_range = string_utils.split(ranges[1], ",")             -- Split the x_range at a comma
      local y_range = string_utils.split(ranges[2], ",")             -- Split the y_range at a comma
      local z_range = string_utils.split(ranges[3], ",")             -- Split the z_range at a comma
      if #x_range ~=2 or #y_range ~=2 or #z_range ~=2 then    -- If there is not exatcly two entries in both the x_range, y_range and z_range, then
        vim.api.nvim_err_writeln("Invalid range values for 3D plot. Use [x_min, x_max; y_min, y_max; z_min, z_max].")   -- Write an error to the log
        return
      end
      xlb, xub = x_range[1]:match("^%s*(.-)%s*$"), x_range[2]:match("^%s*(.-)%s*$")   -- Set the lower bound (xlb) for the first value in the x_range-list and vice versa
      ylb, yub = y_range[1]:match("^%s*(.-)%s*$"), y_range[2]:match("^%s*(.-)%s*$")   -- Set the lower bound (ylb) to the first value in the y_range-list and vice versa
      zlb, zub = z_range[1]:match("^%s*(.-)%s*$"), z_range[2]:match("^%s*(.-)%s*$")   -- Set the lower bound (zlb) to the first value in the z_range-list and vice versa
      plot_type = "3D"
      io_utils.debug_print("Detected 3 ranges: 3D plot with specified z-range")          -- (Optionally) print the detected amount of ranges

    else    -- If an unhandled amount of ranges have been given, then write an error to the log
      vim.api.nvim_err_writeln("Invalid number of range specifications. Use [x_min, x_max], [x_min, x_max; y_min, y_max], or [x_min, x_max; y_min, y_max; z_min, z_max].")
      return
    end
  else
    exprPart = mainExpr   -- If no rangeSpec is found the entire MainExpr is set to the exprPart
    io_utils.debug_print("No rangeSpec found, ExprPart set to MainExpr")   -- (Optionally) print that no rangeSpec was found
  end


  -- d) Split and preprocess the expressions
  -------------------------------------------------------------------------------
  -- Split expressions
  local exprList = string_utils.split_expressions(exprPart)                      -- Split expressions using split_expressions
  io_utils.debug_print("ExprList => " .. table.concat(exprList, ", "))       -- (Optinally) print the split-expressions

  -- Preprocess each expression
  for i, expr in ipairs(exprList) do                                      -- Loop through all expressions
    io_utils.debug_print("Preprocessing exprList[" .. i .. "] => " .. expr)  -- (Optionally) print the expressions to be preprocessed
    exprList[i] = parser.utils.preprocess_equation(expr)                         -- Preprocess all equations with preprocess_equation
  end

  local finalExpr = string_utils.build_multi_expr(exprList)                      -- Combine expressions using build_multi_expr
  io_utils.debug_print("Final preprocessed expressions => " .. finalExpr)    -- (Optionally) print the final preprocessed expressions


  -- e) Determine plot type based on expressions (if not already determined)
  -------------------------------------------------------------------------------
  if plot_type == "2D" then             -- If plot_type is 2D (default) then
    for _, expr in ipairs(exprList) do  -- Loop through all expressions
      if expr:find("y[%[%(%]]") then    -- If any expression contains a "y", then
        plot_type = "3D"                -- Set plot_type to 3D
        io_utils.debug_print("Inferred plot type as 3D based on expression dependencies")  -- (Optionally)  print that a 3D-plot was inferred
        break
      end
    end
  end


  -- f) After potentially updating plot_type, parse ranges again if needed
  -------------------------------------------------------------------------------
  if plot_type == "3D" then               -- If plot_type is 2D, them
    if exprPart:match("y[%[%(%]]") then
      if not rangeSpec then
        xlb, xub, ylb, yub, zlb, zub = -10, -10, nil, nil, nil, nil   -- If no rangeSpec is provided set all ranges to "nil" (defaults to automatic ranges)
      else
        -- Ranges have already been parsed above, so the following is a minor check
        local ranges = io_utils.split(rangeSpec, ";")    -- Split ranges at ;

        if #ranges ==1 then       -- [x_min, x_max], y and z set to Automatic
          ylb, yub, zlb, zub = nil, nil, nil, nil     -- Ensure rangeSpecs not given are set to "nil" (automatic)

        elseif #ranges ==2 then   -- [x_min, x_max; y_min, y_max], z set to Automatic
          zlb, zub = nil, nil     -- Ensure rangeSpecs not given are set to "nil" (automatic)
        end
      end
    end
  end


  -- g) Capture labels by stripping leading backslashes and trimming
  -------------------------------------------------------------------------------
  local labelList = {}
  for _, piece in ipairs(exprList) do                           -- Iterates through all expressions in exprList
    local label = piece:gsub("^\\", ""):match("^%s*(.-)%s*$")   -- Removes backslashes and trims whitespace
    table.insert(labelList, label)                              -- Puts the into labelList
  end


  -- h) Parse style options if curlySpec was found
  -------------------------------------------------------------------------------
  local styleOpts = { hasLegend = false, directives = {} }                        -- Sets default as no legend and no style-spec
  if curlySpec then                                                               -- If a curlySpec (style-spec) has been given, then
    styleOpts = parse_plot_options(curlySpec, #exprList)                          -- call parse_plot_options on the curlySpec
  end


  -- i) Generate plot filename
  -------------------------------------------------------------------------------
  local plotfile = io_utils.get_plot_filename()  -- get a filename using get_plot_filename


  -- j) Generate the Wolfram plot command
  -------------------------------------------------------------------------------
  local plotCommand = generate_plot_command(finalExpr, plotfile, xlb, xub, ylb, yub, zlb, zub, styleOpts, labelList, plot_type)   -- Generate the plot-command
  io_utils.debug_print("Wolfram Plot Command => " .. plotCommand)    -- (optionally) prints the command used for plotting

  async.run_plot_async(plotCommand, plotfile, function(err)       -- use run_plot_async to run the plotCommand asynchronously
    if err then                                                   -- If an error is found, then
      vim.api.nvim_err_writeln("Plot error: " .. err)             -- Print the error to the error-log
      return
    end

    local include_line = "\\includegraphics[width=0.5\\textwidth]{" .. plotfile .. "}"  -- Save the \includegraphics-text
    io_utils.debug_print("Inserting => " .. include_line)                                  -- (Optionally) prints the \includegraphics-text
    vim.fn.append(end_row, include_line)                                                -- Print the includegraphis-text to the buffer
  end)
end




-- 6) Create user command for plot
---------------------------------------------------------------------------------
function M.setup_commands()
  vim.api.nvim_create_user_command("TungstenPlot", function()
    M.insert_plot_from_selection()
  end, { range = true })
end

return M
