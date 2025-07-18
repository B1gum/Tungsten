-- core/parser.lua
-- Parses input strings based on grammar into an AST
-----------------------------------------------------

local lpeg = require("lpeglabel")
local registry = require("tungsten.core.registry")
local space = require("tungsten.core.tokenizer").space
local logger = require("tungsten.util.logger")

local M = {}

local compiled_grammar

function M.get_grammar()
	if not compiled_grammar then
		logger.debug("Tungsten Parser", "Parser: Compiling combined grammar...")
		compiled_grammar = registry.get_combined_grammar()
		if not compiled_grammar then
			logger.error("Tungsten Parser Error", "Parser: Grammar compilation failed. Subsequent parsing will fail.")
			compiled_grammar = lpeg.P(false)
		else
			logger.debug("Tungsten Parser", "Parser: Combined grammar compiled and cached.")
		end
	end
	return compiled_grammar
end

function M.parse(input)
	local current_grammar = M.get_grammar()
	local result, err_label, err_pos = lpeg.match(space * current_grammar * space * -1, input)
	if result then
		return result
	end
	return nil, err_label, err_pos, input
end

function M.reset_grammar()
	logger.info("Tungsten Parser", "Parser: Resetting compiled grammar.")
	compiled_grammar = nil
end

return M
