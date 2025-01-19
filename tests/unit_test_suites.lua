--------------------------------------------------------------------------------
-- unit_test_suites.lua
-- Aggregates suite tables from multiple test files
--------------------------------------------------------------------------------

local parser_unit = require("tungsten.tests.test_parser_unit")
-- local eval_unit   = require("tungsten.tests.test_eval_unit")  -- if you have separate unit tests for evaluation, etc.

local M = {}

-- Merge them all in a single big table
M.all_suites = {}

-- Insert parser sub-suites
for name, func in pairs(parser_unit.get_suites()) do
  M.all_suites[name] = func
end

return M

