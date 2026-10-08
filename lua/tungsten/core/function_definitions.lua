-- Distinguishes symbolic functions from scalar multiplication and expands
-- session-local algebraic definitions before backend rendering.
local constants = require("tungsten.core.constants")

local M = {}
local definitions = {}
local pending_name
local pending_parameters
local context_names
local builtins = { u = true, delta = true, cot = true, sec = true, csc = true }
local binding_nodes = {
	limit = true,
	indefinite_integral = true,
	definite_integral = true,
	ordinary_derivative = true,
	partial_derivative = true,
	summation = true,
	product = true,
}

local function copy(value, substitutions)
	if type(value) ~= "table" then
		return value
	end
	if value.type == "variable" and substitutions and substitutions[value.name] then
		return copy(substitutions[value.name])
	end
	local result = {}
	for key, child in pairs(value) do
		result[key] = copy(child, substitutions)
	end
	return result
end

local function is_builtin(name)
	if builtins[name] then
		return true
	end
	local config = require("tungsten.config")
	for _, opts in pairs(config.backend_opts or {}) do
		local mappings = type(opts) == "table" and opts.function_mappings or {}
		if mappings and (mappings[name] or (name and mappings[name:lower()])) then
			return true
		end
	end
	return false
end

function M.is_callable(name)
	if pending_parameters and pending_parameters[name] then
		return false
	end
	if pending_name == name or definitions[name] or (context_names and context_names[name]) or is_builtin(name) then
		return true
	end
	local config = require("tungsten.config")
	for _, symbolic_name in ipairs(config.symbolic_functions or { "f", "g", "h", "r" }) do
		if symbolic_name == name then
			return true
		end
	end
	return false
end

function M.with_symbolic_names(names, callback)
	local previous = context_names
	context_names = copy(previous or {})
	for name in pairs(names) do
		context_names[name] = true
	end
	local ok, result, err, position, input = pcall(callback)
	context_names = previous
	if not ok then
		error(result, 0)
	end
	return result, err, position, input
end

local function validate_body(node)
	if type(node) ~= "table" then
		return
	end
	if binding_nodes[node.type] then
		error("Function definitions currently support algebraic expressions, not bound-variable calculus notation.", 0)
	end
	for _, child in pairs(node) do
		validate_body(child)
	end
end

function M.parse_definition(text)
	if type(text) ~= "string" then
		return nil
	end
	local name, arguments, operator, rhs = text:match("^%s*([%a][%w]*)%s*%((.-)%)%s*(:?=)%s*(.-)%s*$")
	if not name or rhs:sub(1, 1) == "=" then
		return nil
	end
	local parameters, seen = {}, {}
	for parameter in (arguments .. ","):gmatch("(.-),") do
		parameter = parameter:match("^%s*(.-)%s*$")
		-- f(5) = 25 is an equation, not a definition.
		if not parameter:match("^[%a][%w]*$") then
			return nil
		end
		if constants.is_constant(parameter) then
			return nil, "Function parameters cannot be named constants."
		end
		if seen[parameter] then
			return nil, "Function parameters must be distinct."
		end
		seen[parameter] = true
		table.insert(parameters, parameter)
	end
	if is_builtin(name) then
		return nil, "Cannot redefine a built-in function: " .. name
	end
	if rhs == "" then
		return nil, "Function body cannot be empty."
	end
	local parser = require("tungsten.core.parser")
	local previous, previous_parameters = pending_name, pending_parameters
	pending_name = name
	pending_parameters = seen
	local ok, parsed, err = pcall(parser.parse, rhs)
	pending_name = previous
	pending_parameters = previous_parameters
	if not ok or not parsed or not parsed.series or #parsed.series ~= 1 then
		return nil, "Invalid function body: " .. tostring(err or (not ok and parsed) or "expected one expression")
	end
	local body = parsed.series[1]
	local valid, validation_err = pcall(validate_body, body)
	if not valid then
		return nil, validation_err
	end
	return { name = name, parameters = parameters, body = body, rhs_text = rhs, operator = operator }
end

local function expand(node, stack, depth)
	if type(node) ~= "table" then
		return node
	end
	if depth > 100 then
		error("Function expansion exceeded its depth limit.", 0)
	end
	local result = {}
	for key, child in pairs(node) do
		result[key] = expand(child, stack, depth)
	end
	if result.type ~= "function_call" then
		return result
	end
	local name = result.name_node and result.name_node.name
	local definition = definitions[name]
	if not definition then
		return result
	end
	if stack[name] then
		error("Recursive function definitions are not supported: " .. name, 0)
	end
	if #result.args ~= #definition.parameters then
		error("Wrong number of arguments for function '" .. name .. "'.", 0)
	end
	local substitutions = {}
	for index, parameter in ipairs(definition.parameters) do
		substitutions[parameter] = result.args[index]
	end
	stack[name] = true
	local body = expand(copy(definition.body, substitutions), stack, depth + 1)
	stack[name] = nil
	return body
end

function M.expand(node)
	local ok, result = pcall(expand, node, {}, 0)
	if not ok then
		return nil, result
	end
	return result
end

function M.store(definition)
	local previous = definitions[definition.name]
	definitions[definition.name] = copy(definition)
	local _, err = M.expand(definition.body)
	if err then
		definitions[definition.name] = previous
		return nil, err
	end
	return true
end

function M.clear()
	definitions = {}
end

return M
