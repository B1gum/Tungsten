local M = {}

local config = require("tungsten.config")
local constants = require("tungsten.core.constants")
local backend_util = require("tungsten.backends.util")
local operators = require("tungsten.core.operators")
local common_handlers = require("tungsten.backends.common.handlers")
local util = require("tungsten.backends.util")

local python_symbols = {
	["+"] = "+",
	["-"] = "-",
	["*"] = "*",
	["/"] = "/",
	["^"] = "**",
	["=="] = "==",
	["="] = "==",
	["\\cdot"] = "*",
	["\\times"] = "*",
}

local op_attributes = operators.with_symbols("py", python_symbols)

local function bin_with_parens(node, recur_render)
	local parent_op_data = op_attributes[node.operator]

	if not parent_op_data then
		local logger = require("tungsten.util.logger")
		logger.warn(
			"Tungsten",
			"Tungsten Python Handler (bin_with_parens): Undefined operator '"
				.. tostring(node.operator)
				.. "'. Rendering directly without precedence."
		)
		local rendered_left_unknown = recur_render(node.left)
		local rendered_right_unknown = recur_render(node.right)
		return rendered_left_unknown .. " " .. node.operator .. " " .. rendered_right_unknown
	end

	local py_op_display = parent_op_data.py

	local rendered_left = recur_render(node.left)
	if backend_util.should_wrap_in_parens(parent_op_data, node.left, op_attributes, true) then
		rendered_left = "(" .. rendered_left .. ")"
	end

	local rendered_right = recur_render(node.right)
	if backend_util.should_wrap_in_parens(parent_op_data, node.right, op_attributes, false) then
		rendered_right = "(" .. rendered_right .. ")"
	end

	if py_op_display == "**" then
		return string.format("(%s) ** (%s)", rendered_left, rendered_right)
	elseif py_op_display == "==" then
		return string.format("Eq(%s, %s)", rendered_left, rendered_right)
	end

	return rendered_left .. " " .. py_op_display .. " " .. rendered_right
end

M.handlers = {}

for node_type, handler in pairs(common_handlers) do
	M.handlers[node_type] = handler
end
for node_type, handler in pairs({
	constant = function(node)
		local constant_info = constants.get(node.name)
		if constant_info and constant_info.python then
			return constant_info.python
		end
		return tostring(node.name)
	end,

	binary = bin_with_parens,

	fraction = function(node, recur_render)
		return string.format("(%s) / (%s)", recur_render(node.numerator), recur_render(node.denominator))
	end,
	sqrt = function(node, recur_render)
		if node.index then
			return ("sp.root(%s, %s)"):format(recur_render(node.radicand), recur_render(node.index))
		else
			return ("sp.sqrt(%s)"):format(recur_render(node.radicand))
		end
	end,
	superscript = function(node, recur_render)
		local base_str = recur_render(node.base)
		local exp_str = recur_render(node.exponent)
		return ("(%s) ** (%s)"):format(base_str, exp_str)
	end,
	subscript = function(node, recur_render)
		return ("Symbol('%s_%s')"):format(recur_render(node.base), recur_render(node.subscript))
	end,
	unary = function(node, recur_render)
		local operand_str = recur_render(node.value)
		if node.operator == "-" then
			if node.value.type == "binary" then
				return string.format("(-(%s))", operand_str)
			else
				return string.format("(-%s)", operand_str)
			end
		else
			return node.operator .. operand_str
		end
	end,
	function_call = function(node, recur_render)
		local python_opts = (config.backend_opts and config.backend_opts.python) or {}
		local func_name_map = python_opts.function_mappings or {}
		local func_name_str = (node.name_node and node.name_node.name) or "UnknownFunction"
		local python_func_name = func_name_map[func_name_str:lower()] or func_name_str

		local rendered_args = {}
		if node.args then
			for _, arg_node in ipairs(node.args) do
				table.insert(rendered_args, recur_render(arg_node))
			end
		end
		return ("%s(%s)"):format(python_func_name, table.concat(rendered_args, ", "))
	end,

	solve_system = function(node, recur_render)
		local rendered_equations = util.map_render(node.equations, recur_render)
		local rendered_variables = util.map_render(node.variables, recur_render)

		local equations_str = "[" .. table.concat(rendered_equations, ", ") .. "]"
		local variables_str = "[" .. table.concat(rendered_variables, ", ") .. "]"
		return ("sp.solve(%s, %s)"):format(equations_str, variables_str)
	end,
}) do
	M.handlers[node_type] = handler
end

return M
