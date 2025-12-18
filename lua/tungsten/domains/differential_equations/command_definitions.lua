local evaluator = require("tungsten.core.engine")
local config = require("tungsten.config")
local selection = require("tungsten.util.selection")
local cmd_utils = require("tungsten.util.commands")
local parser = require("tungsten.core.parser")
local ast = require("tungsten.core.ast")

local M = {}

local function is_equation_node(node)
        if not node or type(node) ~= "table" then
                return false
        end

        if node.type == "Equality" then
                return true
        end

        if node.type == "binary" and node.operator == "=" then
                return true
        end

        return false
end

local function build_ode_system(node_list)
        local odes = {}
        local conditions = {}

        for _, n in ipairs(node_list or {}) do
                if n.type == "ode" then
                        table.insert(odes, n)
                elseif n.type == "ode_system" and n.equations then
                        for _, eq in ipairs(n.equations) do
                                table.insert(odes, eq)
                        end
                        if n.conditions then
                                for _, cond in ipairs(n.conditions) do
                                        table.insert(conditions, cond)
                                end
                        end
                elseif is_equation_node(n) then
                        table.insert(conditions, n)
                end
        end

        if #odes == 0 then
                return nil
        end

        return ast.create_ode_system_node(odes, conditions)
end

M.TungstenSolveODE = {
        description = "SolveODE",
        input_handler = function()
                local text = selection.get_visual_selection()
                if not text or text == "" then
                        return nil, nil, "No ODE or ODE system selected."
                end

                local ok, parsed, err_msg = pcall(parser.parse, text, { allow_multiple_relations = true })
                if not ok or not parsed or not parsed.series or #parsed.series == 0 then
                        return nil, text, err_msg or tostring(parsed)
                end

                local ode_system = build_ode_system(parsed.series)
                if not ode_system then
                        return nil, text, "Selection must contain an ODE or ODE system"
                end

                return ode_system, text, nil
        end,
        prepare_args = function(node, _)
                local final
                if node.type == "ode" then
                        final = ast.create_ode_system_node({ node }, node.conditions)
                elseif node.type == "binary" and node.operator == "=" then
                        final = ast.create_ode_system_node({ ast.create_ode_node(node.left, node.right) })
                else
                        final = node
                end
		return { final, config.numeric_mode }
	end,
	task_handler = function(ast_node, numeric_mode, cb)
		evaluator.evaluate_async(ast_node, numeric_mode, cb)
	end,
	separator = " \\rightarrow ",
}

local function simple_transform(name, constructor)
	return {
		description = name,
		input_handler = function()
			return cmd_utils.parse_selected_latex("expression")
		end,
		prepare_args = function(node, _)
			return { constructor(node), config.numeric_mode }
		end,
		task_handler = function(a, numeric_mode, cb)
			evaluator.evaluate_async(a, numeric_mode, cb)
		end,
		separator = " \\rightarrow ",
	}
end

M.TungstenWronskian = simple_transform("Wronskian", function(n)
	return n
end)
M.TungstenLaplace = simple_transform("Laplace", ast.create_laplace_transform_node)
M.TungstenInverseLaplace = simple_transform("InverseLaplace", ast.create_inverse_laplace_transform_node)
M.TungstenConvolve = simple_transform("Convolve", function(n)
	return n
end)

return M
