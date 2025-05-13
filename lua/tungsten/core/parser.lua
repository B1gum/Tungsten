local lpeg     = require "lpeg"
local grammar  = require "tungsten.domains.arithmetic.grammar"
local space    = require("tungsten.core.tokenizer").space  -- moved file

local M = {}

function M.parse(input)
  return lpeg.match(space * grammar * space * -1, input)
end

return M
