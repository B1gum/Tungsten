--------------------------------------------------------------------------------
-- io_utils.lua
-- Plot name-generation, debug-printing and so on.
--------------------------------------------------------------------------------

local M = {}

-- Debug printing
local DEBUG = true  -- Set to true to enable debug messages

local function debug_print(msg)
  if DEBUG then
    print("DEBUG: " .. msg)
  end
end

M.debug_print = debug_print

-- Function to find a filename for plots
function M.get_plot_filename()
  local timestamp = os.date("%Y%m%d_%H%M%S")
  return "plot_" .. timestamp .. ".pdf"
end

return M
