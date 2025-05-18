-- tests/helpers/mock_utils.lua
local spy = require('luassert.spy')

local M = {}

function M.mock_module(module_name, mock_table)
  mock_table = mock_table or {}
  for key, value in pairs(mock_table) do
    if type(value) == 'function' then
      mock_table[key] = spy.new(value)
    end
  end
  package.loaded[module_name] = mock_table
  return mock_table
end

function M.reset_modules(module_names)
  for _, name in ipairs(module_names) do
    package.loaded[name] = nil
  end
end

function M.create_empty_mock_module(module_name, function_names)
  local mock = {}
  if function_names then
    for _, fn_name in ipairs(function_names) do
      mock[fn_name] = spy.new(function() end)
    end
  end
  package.loaded[module_name] = mock
  return mock
end

return M
