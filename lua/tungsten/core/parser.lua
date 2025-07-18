-- core/parser.lua
-- Parses input strings based on grammar into an AST
-----------------------------------------------------

local lpeg = require("lpeglabel")
local registry = require("tungsten.core.registry")
local space = require("tungsten.core.tokenizer").space
local logger = require("tungsten.util.logger")
local error_handler = require("tungsten.util.error_handler")

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

local label_messages = {
	extra_input = "unexpected text after expression",
	fail = "syntax error",
}

function M.parse(input)
	local current_grammar = M.get_grammar()
	local pattern = space * current_grammar * (space * -1 + lpeg.T("extra_input"))
	local result, err_label, err_pos = lpeg.match(pattern, input)
	if result then
		return result
	end
	local msg = label_messages[err_label] or tostring(err_label)
	if err_pos then
		msg = msg .. " at " .. error_handler.format_line_col(input, err_pos)
	end
	return nil, msg, err_pos, input
end

function M.reset_grammar()
	logger.info("Tungsten Parser", "Parser: Resetting compiled grammar.")
	compiled_grammar = nil
end

return M
