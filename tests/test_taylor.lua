--------------------------------------------------------------------------------
-- test_taylor.lua
--------------------------------------------------------------------------------

local parser     = require("tungsten.utils.parser")
local async      = require("tungsten.async")
local test_utils = require("tungsten.tests.test_utils")

local M = {}

function M.run_taylor_test()
  test_utils.log_header("Taylor Series Test")

  local expansions = {
    { "\\cos(x)", "x", "0", "5" },
    { "\\sin\\left(\\frac{x}{2}\\right)", "x", "0", "4" },
    -- ...
  }

  local i = 1
  local function run_next()
    if i > #expansions then
      return
    end
    local latex_expr, var, x0, order = expansions[i][1], expansions[i][2], expansions[i][3], expansions[i][4]
    i = i + 1

    local preproc = parser.preprocess_equation(latex_expr)
    local wolfram_code = string.format(
      "ToString[Normal[Series[%s, {%s, %s, %s}]], TeXForm]",
      preproc, var, x0, order
    )

    test_utils.append_log_line("Input => " .. latex_expr)
    test_utils.append_log_line("Preprocessed => " .. preproc)
    test_utils.append_log_line("Wolfram code => " .. wolfram_code)

    async.run_wolframscript_async(
      { "wolframscript", "-code", wolfram_code, "-format", "OutputForm" },
      function(result, err)
        if err then
          test_utils.append_log_line("ERROR: " .. err)
        elseif not result or result:find("$Failed") then
          test_utils.append_log_line("ERROR: Taylor returned $Failed")
        else
          test_utils.append_log_line("Taylor Series => " .. result)
        end
        run_next()
      end
    )
  end

  run_next()
end

return M
