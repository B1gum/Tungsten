--------------------------------------------------------------------------------
-- colors.lua
-- Handles color definitions and logic for Wolfram plotting
--------------------------------------------------------------------------------

local M = {}

-- A list of custom hex colors
local defaultColors = {
  "#FFA4E9", "#2C9C38", "#F0A830", "#0B486B",
  "#E3DAC9", "#272941", "#318CE7", "#1CCEB7",
  "#008080", "#1B4D3E", "#841B2D", "#7b1E7A",
  "#E95081", "#000000"
}

local defaultColorIndex = 1

-- Recognized color names (convert to e.g. "Red", "Blue" in Wolfram)
local knownColors = {
  red = true, blue = true, green = true, black = true,
  brown = true, gray = true, orange = true, purple = true,
  yellow = true, cyan = true, magenta = true
}

-- Convert hex (#RRGGBB) to Wolfram's RGBColor[r, g, b]
local function hex_to_rgbcolor(hex)
  local r, g, b = hex:match("^#(%x%x)(%x%x)(%x%x)$")
  r, g, b = tonumber(r, 16) / 255, tonumber(g, 16) / 255, tonumber(b, 16) / 255
  return string.format("RGBColor[%f, %f, %f]", r, g, b)
end

-- Return the next default color in the list, cycling around
local function get_next_default_color()
  local color = defaultColors[defaultColorIndex]
  defaultColorIndex = defaultColorIndex + 1
  if defaultColorIndex > #defaultColors then
    defaultColorIndex = 1
  end
  return hex_to_rgbcolor(color)
end

-- Expose anything we need outside
M.knownColors = knownColors
M.get_next_default_color = get_next_default_color

return M
