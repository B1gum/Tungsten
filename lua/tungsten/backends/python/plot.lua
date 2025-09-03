local base = require("tungsten.backends.plot_base")
local logger = require("tungsten.util.logger")

local M = setmetatable({}, { __index = base })

function M.plot_async(_opts, callback)
  logger.debug("Python plot", "plot_async_called")
  if callback then
    callback(nil)
  end
end

return M
