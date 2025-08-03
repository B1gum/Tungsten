-- tungsten/core/persistent_vars.lua
-- Utilities for parsing and storing persistent variable definitions

local parser = require("tungsten.core.parser")
local manager = require("tungsten.backends.manager")
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

function M.latex_to_backend_code(variable_name, rhs_latex)
	local ok, ast_or_err, err_msg = pcall(parser.parse, rhs_latex)
	if not ok or not ast_or_err then
		return nil, "Failed to parse LaTeX definition for '" .. variable_name .. "': " .. tostring(err_msg or ast_or_err)
	end
	local ast = ast_or_err

	local backend = manager.current()
	if not backend or not backend.ast_to_code then
		return nil, "No active backend"
	end

	local conversion_ok, code_or_err = pcall(backend.ast_to_code, ast)
	if not conversion_ok or not code_or_err or type(code_or_err) ~= "string" then
		return nil,
			"Failed to convert definition AST to backend code for '" .. variable_name .. ": " .. tostring(code_or_err)
	end

	return code_or_err, nil
end

local function get_backend()
	local backend = manager.current()
	if backend == nil then
		return nil
	end
	return backend
end

function M.write_async(name, backend_def, callback)
	local backend = get_backend()
	if backend and type(backend.persistent_write_async) == "function" then
		backend.persistent_write_async(name, backend_def, callback)
		return
	end
	local code = string.format("%s %s %s", tostring(name), config.persistent_variable_assignment_operator, backend_def)
	if backend and type(backend.evaluate_async) == "function" then
		backend.evaluate_async(nil, { code = code }, callback)
	elseif callback then
		callback(nil, "No active backend")
	end
end

function M.read_async(name, callback)
	local backend = get_backend()
	if backend and type(backend.persistent_read_async) == "function" then
		backend.persistent_read_async(name, callback)
		return
	end
	if backend and type(backend.evaluate_async) == "function" then
		backend.evaluate_async(nil, { code = tostring(name) }, callback)
	elseif callback then
		callback(nil, "No active backend")
	end
end

function M.store(name, backend_def, callback)
	state.persistent_variables = state.persistent_variables or {}
	state.persistent_variables[name] = backend_def
	M.write_async(name, backend_def, callback)
end

return M
