-- which_key.lua
-- Module for which_key integration

local ok, wk = pcall(require, "which-key")
if not ok then
	return {}
end

local config = require("tungsten.config")

local mappings = {
	mode = { "v" },
	{ "<leader>t", group = "Tungsten" },

	{ "<leader>te", group = "Evaluate" },
	{ "<leader>tee", ":<C-u>TungstenEvaluate<CR>", desc = "Evaluate Expression" },
	{ "<leader>ted", ":<C-u>TungstenDefinePersistentVariable<CR>", desc = "Define Persistent Variable" },
	{ "<leader>tea", ":<C-u>TungstenShowAST<CR>", desc = "Show AST" },

	{ "<leader>ts", group = "Solve" },
	{ "<leader>tss", ":<C-u>TungstenSolve<CR>", desc = "Solve Equation" },
	{ "<leader>tsx", ":<C-u>TungstenSolveSystem<CR>", desc = "Solve System of Equations" },

	{ "<leader>tl", group = "Linear Algebra" },
	{ "<leader>tlg", ":<C-u>TungstenGaussEliminate<CR>", desc = "Gauss-Jordan Elimination" },
	{ "<leader>tli", ":<C-u>TungstenLinearIndependent<CR>", desc = "Linear Independence Test" },
	{ "<leader>tlr", ":<C-u>TungstenRank<CR>", desc = "Rank of Matrix" },

	{ "<leader>tle", group = "Eigen" },
	{ "<leader>tlev", ":<C-u>TungstenEigenvalue<CR>", desc = "Eigenvalues" },
	{ "<leader>tlee", ":<C-u>TungstenEigenvector<CR>", desc = "Eigenvectors" },
	{ "<leader>tles", ":<C-u>TungstenEigensystem<CR>", desc = "Eigensystem" },

	{ "<leader>td", group = "Differential Equations" },
	{ "<leader>tdo", ":<C-u>TungstenSolveODE<CR>", desc = "Solve ODE" },
	{ "<leader>tds", ":<C-u>TungstenSolveODESystem<CR>", desc = "Solve ODE System" },
	{ "<leader>tdw", ":<C-u>TungstenWronskian<CR>", desc = "Wronskian" },
	{ "<leader>tdl", ":<C-u>TungstenLaplace<CR>", desc = "Laplace Transform" },
	{ "<leader>tdi", ":<C-u>TungstenInverseLaplace<CR>", desc = "Inverse Laplace Transform" },
	{ "<leader>tdc", ":<C-u>TungstenConvolve<CR>", desc = "Convolution" },

	{ "<leader>tc", group = "Cache" },
	{ "<leader>tcc", ":<C-u>TungstenClearCache<CR>", desc = "Clear Cache" },
	{ "<leader>tcp", ":<C-u>TungstenClearPersistentVars<CR>", desc = "Clear Persistent Vars" },
	{ "<leader>tcv", ":<C-u>TungstenViewActiveJobs<CR>", desc = "View Active Jobs" },
	{ "<leader>tm", "<cmd>TungstenPalette<cr>", desc = "Open Command Palette" },

	{ "<leader>tt", group = "Toggle" },
	{ "<leader>ttn", ":<C-u>TungstenToggleNumericMode<CR>", desc = "Toggle Numeric Mode" },
	{ "<leader>ttd", ":<C-u>TungstenToggleDebugMode<CR>", desc = "Toggle Debug Mode" },
}

if config.enable_default_mappings then
	wk.add(mappings)
end

return { mappings = mappings }
