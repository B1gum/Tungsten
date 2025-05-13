local lpeg    = require "lpeg"
local grammar = require "tungsten.parser.grammar"
local space   = require("tungsten.parser.tokens").space

local core = {}

function core.parse(input)
  return lpeg.match(space * grammar * space * -1, input)
end

return core

