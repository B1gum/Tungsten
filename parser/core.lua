local lpeg    = require "lpeg"
local grammar = require "parser.grammar"
local space   = require("parser.tokens").space

local core = {}

function core.parse(input)
  return lpeg.match(space * grammar * space * -1, input)
end

return core

