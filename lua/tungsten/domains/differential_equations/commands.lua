-- lua/tungsten/domains/differential_equations/commands.lua
-- Defines the implementation for user-facing commands in the differential_equations domain.

local workflow = require("tungsten.core.workflow")
local definitions = require("tungsten.domains.differential_equations.command_definitions")

local M = {}

local function run(definition)
	workflow.run(definition)
end

M.solve_ode_command = function(_)
	run(definitions.TungstenSolveODE)
end

M.wronskian_command = function(_)
	run(definitions.TungstenWronskian)
end

M.laplace_command = function(_)
	run(definitions.TungstenLaplace)
end

M.inverse_laplace_command = function(_)
	run(definitions.TungstenInverseLaplace)
end

M.convolve_command = function(_)
	run(definitions.TungstenConvolve)
end

M.commands = {
	{
		name = "TungstenSolveODE",
		func = M.solve_ode_command,
		opts = { range = true, desc = "Solve the selected ODE or ODE system" },
	},
	{
		name = "TungstenSolveODESystem",
		func = M.solve_ode_command,
		opts = { range = true, desc = "Solve the selected ODE system (alias for TungstenSolveODE)" },
	},
	{
		name = "TungstenWronskian",
		func = M.wronskian_command,
		opts = { range = true, desc = "Calculate the Wronskian of the selected functions" },
	},
	{
		name = "TungstenLaplace",
		func = M.laplace_command,
		opts = { range = true, desc = "Calculate the Laplace transform of the selected function" },
	},
	{
		name = "TungstenInverseLaplace",
		func = M.inverse_laplace_command,
		opts = { range = true, desc = "Calculate the inverse Laplace transform of the selected function" },
	},
	{
		name = "TungstenConvolve",
		func = M.convolve_command,
		opts = { range = true, desc = "Calculate the convolution of the two selected functions" },
	},
}

return M
