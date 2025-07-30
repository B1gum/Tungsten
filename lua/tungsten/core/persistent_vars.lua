-- tungsten/core/persistent_vars.lua
-- Utilities for parsing and storing persistent variable definitions

local parser = require("tungsten.core.parser")
local wolfram_backend = require("tungsten.backends.wolfram")
local string_util = require("tungsten.util.string")
local config = require("tungsten.config")
local state = require("tungsten.state")

local M = {}

function M.parse_definition(text)
	if not text or text == "" then
		return nil, nil, "No text selected for variable definition."
	end

	local operator = config.persistent_variable_assignment_operator
	local operator_position = text:find(operator, 1, true)
	if not operator_position then
		return nil, nil, "No assignment operator ('" .. operator .. "') found in selection."
	end

	local variable_name = string_util.trim(text:sub(1, operator_position - 1))
	local rhs = string_util.trim(text:sub(operator_position + #operator))

	if variable_name == "" then
		return nil, nil, "variable name cannot be empty."
	end
	if rhs == "" then
		return nil, nil, "Variable definition (LaTeX) cannot be empty."
	end

	return variable_name, rhs, nil
end

function M.latex_to_wolfram(variable_name, rhs_latex)
	local ok, ast_or_err, err_msg = pcall(parser.parse, rhs_latex)
	if not ok or not ast_or_err then
		return nil, "Failed to parse LaTeX definition for '" .. variable_name .. "': " .. tostring(err_msg or ast_or_err)
	end
	local ast = ast_or_err

	local conversion_ok, wolfram_or_err = pcall(wolfram_backend.ast_to_wolfram, ast)
	if not conversion_ok or not wolfram_or_err or type(wolfram_or_err) ~= "string" then
		return nil,
			"Failed to convert definition AST to wolfram string for '" .. variable_name .. "': " .. tostring(wolfram_or_err)
	end

	return wolfram_or_err, nil
end

function M.store(name, wolfram_def)
	state.persistent_variables = state.persistent_variables or {}
	state.persistent_variables[name] = wolfram_def
end

return M
