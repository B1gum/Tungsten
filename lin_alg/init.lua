--------------------------------------------------------------------------------
-- init.lua
-- Main module for linear-algebra functionality.
--------------------------------------------------------------------------------

local M = {}

local eval = require("tungsten.lin_alg.async_eval")

function M.setup_commands()
  ------------------------------------------------------------------------------
  -- Evaluate a matrix expression (with +, -, adjacency => multiply)
  ------------------------------------------------------------------------------
  vim.api.nvim_create_user_command("TungstenMatrixEval", function(opts)
    eval.evaluate_expr_async()
  end, {
    nargs = "?",
    desc = "Evaluate a matrix expression with +, -, and multiplication (visual selection)",
  })

  ------------------------------------------------------------------------------
  -- Determinant
  ------------------------------------------------------------------------------
  vim.api.nvim_create_user_command("TungstenMatrixDet", function(opts)
    eval.evaluate_det_async()
  end, {
    nargs = "?",
    desc = "Evaluate the determinant of the selected matrix (visual selection)",
  })

  ------------------------------------------------------------------------------
  -- Inverse
  ------------------------------------------------------------------------------
  vim.api.nvim_create_user_command("TungstenMatrixInv", function(opts)
    eval.evaluate_inv_async()
  end, {
    nargs = "?",
    desc = "Evaluate the inverse of the selected matrix (visual selection)",
  })

  ------------------------------------------------------------------------------
  -- Transpose
  ------------------------------------------------------------------------------
  vim.api.nvim_create_user_command("TungstenMatrixTranspose", function(opts)
    eval.evaluate_transpose_async()
  end, {
    nargs = "?",
    desc = "Evaluate the transpose of the selected matrix (visual selection)",
  })

  ------------------------------------------------------------------------------
  -- Eigenvalues
  ------------------------------------------------------------------------------
  vim.api.nvim_create_user_command("TungstenMatrixEigenvalues", function(opts)
    eval.evaluate_eigenvalues_async()
  end, {
    nargs = "?",
    desc = "Evaluate the eigenvalues of the selected matrix (visual selection)",
  })

  ------------------------------------------------------------------------------
  -- Eigenvectors
  ------------------------------------------------------------------------------
  vim.api.nvim_create_user_command("TungstenMatrixEigenvectors", function(opts)
    eval.evaluate_eigenvectors_async()
  end, {
    nargs = "?",
    desc = "Evaluate the eigenvectors of the selected matrix (visual selection)",
  })

  ------------------------------------------------------------------------------
  -- Eigensystem (returns {eigenvalues, eigenvectors})
  ------------------------------------------------------------------------------
  vim.api.nvim_create_user_command("TungstenMatrixEigensystem", function(opts)
    eval.evaluate_eigensystem_async()
  end, {
    nargs = "?",
    desc = "Evaluate the eigen-system of the selected matrix (visual selection)",
  })
end

return M
