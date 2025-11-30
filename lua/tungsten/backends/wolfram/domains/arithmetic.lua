local M = {}

local config = require("tungsten.config")
local constants = require("tungsten.core.constants")
local backend_util = require("tungsten.backends.util")
local operators = require("tungsten.core.operators")
local common_handlers = require("tungsten.backends.common.handlers")
local util = require("tungsten.backends.util")

local wolfram_symbols = {
	["+"] = "+",
	["-"] = "-",
	["*"] = "*",
	["/"] = "/",
	["^"] = "^",
	["=="] = "==",
	["="] = "==",
	["\\cdot"] = "*",
	["\\times"] = "*",
}

local op_attributes = operators.with_symbols("wolfram", wolfram_symbols)

local function bin_with_parens(node, recur_render)
	local parent_op_data = op_attributes[node.operator]

	if not parent_op_data then
		local logger = require("tungsten.util.logger")
		logger.warn(
			"Tungsten",
			"Tungsten Wolfram Handler (bin_with_parens): Undefined operator '"
				.. tostring(node.operator)
				.. "'. Rendering directly without precedence."
		)
		local rendered_left_unknown = recur_render(node.left)
		local rendered_right_unknown = recur_render(node.right)
		return rendered_left_unknown .. " " .. node.operator .. " " .. rendered_right_unknown
	end

	local wolfram_op_display = parent_op_data.wolfram

	local rendered_left = recur_render(node.left)
	if backend_util.should_wrap_in_parens(parent_op_data, node.left, op_attributes, true) then
		rendered_left = "(" .. rendered_left .. ")"
	end
	local rendered_right = recur_render(node.right)
	if backend_util.should_wrap_in_parens(parent_op_data, node.right, op_attributes, false) then
		rendered_right = "(" .. rendered_right .. ")"
	end

	if wolfram_op_display == "^" then
		return string.format("Power[%s, %s]", rendered_left, rendered_right)
	end

	return rendered_left .. " " .. wolfram_op_display .. " " .. rendered_right
end

M.handlers = {}

for node_type, handler in pairs(common_handlers) do
	M.handlers[node_type] = handler
end

for node_type, handler in pairs({
	constant = function(node)
		local constant_info = constants.get(node.name)
		if constant_info and constant_info.wolfram then
			return constant_info.wolfram
		end
		return tostring(node.name)
	end,

	binary = bin_with_parens,

	fraction = function(node, recur_render)
		return string.format("(%s) / (%s)", recur_render(node.numerator), recur_render(node.denominator))
	end,
	sqrt = function(node, recur_render)
		if node.index then
			return ("Surd[%s, %s]"):format(recur_render(node.radicand), recur_render(node.index))
		else
			return ("Sqrt[%s]"):format(recur_render(node.radicand))
		end
	end,
	superscript = function(node, recur_render)
		local base_str = recur_render(node.base)
		local exp_str = recur_render(node.exponent)
		return ("Power[%s, %s]"):format(base_str, exp_str)
	end,
	subscript = function(node, recur_render)
		return ("Subscript[%s, %s]"):format(recur_render(node.base), recur_render(node.subscript))
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
		local wolfram_opts = (config.backend_opts and config.backend_opts.wolfram) or {}
		local func_name_map = wolfram_opts.function_mappings or {}
		local func_name_str = (node.name_node and node.name_node.name) or "UnknownFunction"
		local wolfram_func_name = func_name_map[func_name_str:lower()]

		if not wolfram_func_name then
			wolfram_func_name = func_name_str:match("^%a") and (func_name_str:sub(1, 1):upper() .. func_name_str:sub(2))
				or func_name_str
			local logger = require("tungsten.util.logger")
			logger.warn(
				"Tungsten",
				("Tungsten Wolfram Handler: No specific mapping for function '%s'. Using form '%s'."):format(
					func_name_str,
					wolfram_func_name
				)
			)
		end

		local rendered_args = {}
		if node.args then
			for _, arg_node in ipairs(node.args) do
				table.insert(rendered_args, recur_render(arg_node))
			end
		end
		return ("%s[%s]"):format(wolfram_func_name, table.concat(rendered_args, ", "))
	end,

	solve_system = function(node, recur_render)
		local rendered_equations = util.map_render(node.equations, recur_render)
		local rendered_variables = util.map_render(node.variables, recur_render)

		local equations_str = "{" .. table.concat(rendered_equations, ", ") .. "}"
		local variables_str = "{" .. table.concat(rendered_variables, ", ") .. "}"

		return ("Solve[%s, %s]"):format(equations_str, variables_str)
	end,
}) do
	M.handlers[node_type] = handler
end

return M
