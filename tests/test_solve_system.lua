--------------------------------------------------------------------------------
-- test_solve_system.lua
--------------------------------------------------------------------------------

local parser     = require("tungsten.utils.parser")
local async      = require("tungsten.async")
local test_utils = require("tungsten.tests.test_utils")

local M = {}

function M.run_solve_system_test()
  test_utils.log_header("Solve System of Equations Test")

  local systems = {
    { "x + y = 5", "x - y = 1" },
    { "x^2 + y^2 = 4", "x = y" },
    -- ...
  }

  local i = 1
  local function run_next()
    if i > #systems then
      return
    end
    local sys = systems[i]
    i = i + 1

    local eqs_str = table.concat(sys, ", ")
    test_utils.append_log_line("System => " .. eqs_str)

    local preproc = {}
    for _, eq_latex in ipairs(sys) do
      local eq_pre = parser.preprocess_equation(eq_latex)
      eq_pre = eq_pre:gsub("([^=])=([^=])", "%1==%2")
      table.insert(preproc, eq_pre)
    end

    test_utils.append_log_line("Preprocessed => " .. table.concat(preproc, " ; "))

    local variables = { "x", "y" }
    async.run_solve_system_async(preproc, variables, function(result, err)
      if err then
        test_utils.append_log_line("ERROR: " .. err)
      elseif not result or result:find("$Failed") then
        test_utils.append_log_line("ERROR: system solve returned $Failed")
      else
        test_utils.append_log_line("System Solution => " .. result)
      end
      run_next()
    end)
  end

  run_next()
end

return M
