--------------------------------------------------------------------------------
-- command.lua
-- Generates the Wolfram plot command (Plot[...] or Plot3D[...]) given expressions
--------------------------------------------------------------------------------

local io_utils = require("tungsten.utils.io_utils")

local M = {}

-- Build the final 2D or 3D plot command
-- Example usage:
--   generate_plot_command("Sin[x]", "plot_20250118.pdf", -1, 1, nil, nil, nil, nil, styleOpts, labels, "2D")
function M.generate_plot_command(expr, plotfile, xlb, xub, ylb, yub, zlb, zub, styleOpts, labels, plot_type)
  local plotCommand = ""
  local varRangeX = ""
  local varRangeY = ""

  -- If x-range is specified
  if xlb and xub then
    varRangeX = string.format("{x, %s, %s}", xlb, xub)
  else
    varRangeX = "{x, -10, 10}"
    io_utils.debug_print("No x-rangeSpec found, using default range: " .. varRangeX)
  end

  -- If 3D, handle y-range
  if plot_type == "3D" then
    if ylb and yub then
      varRangeY = string.format("{y, %s, %s}", ylb, yub)
    else
      varRangeY = "{y, -10, 10}"
      io_utils.debug_print("No y-rangeSpec found, using default range: " .. varRangeY)
    end
  end

  -- 2D
  if plot_type == "2D" then
    -- Build PlotRange
    local plotRange = ""
    if ylb and yub then
      plotRange = string.format("PlotRange -> {{%s, %s}, {%s, %s}}", xlb, xub, ylb, yub)
    else
      plotRange = string.format("PlotRange -> {{%s, %s}, Automatic}", xlb or -10, xub or 10)
    end

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

    local plotStyle = (#styleOpts.directives > 0)
      and "PlotStyle -> {" .. table.concat(styleOpts.directives, ", ") .. "}"
      or "PlotStyle -> Automatic"

    plotCommand = string.format("Plot[%s, %s, %s, %s%s]",
      expr, varRangeX, plotStyle, plotRange,
      (plotLegends ~= "" and (", " .. plotLegends) or "")
    )

  -- 3D
  elseif plot_type == "3D" then
    local plotRange = ""
    if xlb and xub and ylb and yub and zlb and zub then
      plotRange = string.format("PlotRange -> {{%s, %s}, {%s, %s}, {%s, %s}}", xlb, xub, ylb, yub, zlb, zub)
    elseif xlb and xub and ylb and yub then
      plotRange = string.format("PlotRange -> {{%s, %s}, {%s, %s}, Automatic}", xlb, xub, ylb, yub)
    else
      plotRange = string.format("PlotRange -> {{%s, %s}, Automatic, Automatic}", xlb or -10, xub or 10)
    end

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

    local plotStyle = (#styleOpts.directives > 0)
      and "PlotStyle -> {" .. table.concat(styleOpts.directives, ", ") .. "}"
      or "PlotStyle -> Automatic"

    plotCommand = string.format("Plot3D[%s, %s, %s, %s, %s%s]",
      expr, varRangeX, varRangeY, plotStyle, plotRange,
      (plotLegends ~= "" and (", " .. plotLegends) or "")
    )
  else
    error("Unknown plot type: " .. plot_type)
  end

  io_utils.debug_print("Generated Plot Command: " .. plotCommand)
  return plotCommand
end

return M

