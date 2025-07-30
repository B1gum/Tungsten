local evaluator = require("tungsten.core.engine")
local config = require("tungsten.config")
local cmd_utils = require("tungsten.util.commands")
local ast = require("tungsten.core.ast")

local M = {}

M.TungstenSolveODE = {
    description = "SolveODE",
    input_handler = function()
        return cmd_utils.parse_selected_latex("ODE or ODE system")
    end,
    prepare_args = function(node, _)
        local final
        if node.type == "ode" then
            final = ast.create_ode_system_node({ node })
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

M.TungstenWronskian = simple_transform("Wronskian", function(n) return n end)
M.TungstenLaplace = simple_transform("Laplace", ast.create_laplace_transform_node)
M.TungstenInverseLaplace = simple_transform("InverseLaplace", ast.create_inverse_laplace_transform_node)
M.TungstenConvolve = simple_transform("Convolve", function(n) return n end)

return M

