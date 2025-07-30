local workflow = require("tungsten.core.workflow")
local definitions = require("tungsten.domains.linear_algebra.command_definitions")

local M = {}

local function run(definition)
	workflow.run(definition)
end

M.tungsten_gauss_eliminate_command = function(_)
	run(definitions.TungstenGaussEliminate)
end

M.tungsten_linear_independent_command = function(_)
	run(definitions.TungstenLinearIndependent)
end

M.tungsten_rank_command = function(_)
	run(definitions.TungstenRank)
end

M.tungsten_eigenvalue_command = function(_)
	run(definitions.TungstenEigenvalue)
end

M.tungsten_eigenvector_command = function(_)
	run(definitions.TungstenEigenvector)
end

M.tungsten_eigensystem_command = function(_)
	run(definitions.TungstenEigensystem)
end

M.commands = {
	{
		name = "TungstenGaussEliminate",
		func = M.tungsten_gauss_eliminate_command,
		opts = { range = true, desc = "Perform Gaussian elimination (Row Reduce) on the selected matrix" },
	},
	{
		name = "TungstenLinearIndependent",
		func = M.tungsten_linear_independent_command,
		opts = { range = true, desc = "Test if selected vectors/matrix rows or columns are linearly independent" },
	},
	{
		name = "TungstenRank",
		func = M.tungsten_rank_command,
		opts = { range = true, desc = "Calculate the rank of the selected LaTeX matrix" },
	},
	{
		name = "TungstenEigenvalue",
		func = M.tungsten_eigenvalue_command,
		opts = { range = true, desc = "Calculate the eigenvalues of the selected LaTeX matrix" },
	},
	{
		name = "TungstenEigenvector",
		func = M.tungsten_eigenvector_command,
		opts = { range = true, desc = "Calculate the eigenvectors of the selected LaTeX matrix" },
	},
	{
		name = "TungstenEigensystem",
		func = M.tungsten_eigensystem_command,
		opts = {
			range = true,
			desc = "Calculate the eigensystem (eigenvalues and eigenvectors) of the selected LaTeX matrix",
		},
	},
}

return M
