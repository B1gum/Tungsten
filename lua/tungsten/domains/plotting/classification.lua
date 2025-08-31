local M = {}

local helpers = require("tungsten.domains.plotting.helpers")

-- TODO: Placeholder implementation
local function detect_free_variables(expr)
  return helpers.extract_param_names(expr)
end

function M.analyze(ast, opts)
  opts = opts or {}
  local vars = detect_free_variables(ast)
  local result = {
    series = {
      {
        expr = ast,
      },
    },
  }

  if #vars == 1 then
    result.dim = 2
    result.form = "explicit"
  elseif #vars == 2 then
    result.dim = 3
    result.form = "explicit"
  end

  return result
end

return M
