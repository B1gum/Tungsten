-- which_key.lua
-- Module for which_key integration
-------------------------------------------------------------------------------------------

local wk = require "which-key"

wk.add({
  mode = { "v" },
  {
    "<leader>t",
    group = "Tungsten",
  },
  {
    "<leader>te",
    group = "Evaluate",
  },
  {
    "<leader>tee",
    ":<C-u>TungstenEvaluate<CR>",
    desc = "Evaluate Expression",
  },
  {
    "<leader>ted",
    ":<C-u>TungstenDefinePersistentVariable<CR>",
    desc = "Define Persistent Variable",
  },
  {
    "<leader>ts",
    group = "Solve",
  },
  {
    "<leader>tss",
    ":<C-u>TungstenSolve<CR>",
    desc = "Solve Equation",
  },
  {
    "<leader>tsx",
    ":<C-u>TungstenSolveSystem<CR>",
    desc = "Solve System of Equations",
  },
  {
    "<leader>tl",
    group = "Linear Algebra",
  },
  {
    "<leader>tlg",
    ":<C-u>TungstenGaussEliminate<CR>",
    desc = "Gauss-Jordan Elimination",
  },
  {
    "<leader>tli",
    ":<C-u>TungstenLinearIndependent<CR>",
    desc = "Linear Independence Test",
  },
  {
    "<leader>tlr",
    ":<C-u>TungstenRank<CR>",
    desc = "Rank of Matrix",
  },
  {
    "<leader>tle",
    group = "Eigen",
  },
  {
    "<leader>tlev",
    ":<C-u>TungstenEigenvalue<CR>",
    desc = "Eigenvalues",
  },
  {
    "<leader>tlee",
    ":<C-u>TungstenEigenvector<CR>",
    desc = "Eigenvectors",
  },
  {
    "<leader>tles",
    ":<C-u>TungstenEigensystem<CR>",
    desc = "Eigensystem",
  },
  {
    "<leader>tc",
    group = "Cache",
  },
  {
    "<leader>tcc",
    ":<C-u>TungstenClearCache<CR>",
    desc = "Clear Cache",
  },
  {
    "<leader>tcv",
    ":<C-u>TungstenViewActiveJobs<CR>",
    desc = "View Active Jobs",
  },
  {
    "<leader>tm",
    function()
      require("tungsten.ui").open()
    end,
    desc = "Open Command Palette",
  },
})
