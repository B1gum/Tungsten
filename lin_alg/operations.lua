--------------------------------------------------------------------------------
-- operations.lua
-- Determinant, inverse, transpose, etc.
--------------------------------------------------------------------------------

local M = {}

function M.det(expr)
  return string.format("Det[%s]", expr)
end

function M.inv(expr)
  return string.format("Inverse[%s]", expr)
end

function M.transpose(expr)
  return string.format("Transpose[%s]", expr)
end

function M.eigenvalues(expr)
  return string.format("Eigenvalues[%s]", expr)
end

function M.eigenvectors(expr)
  return string.format("Eigenvectors[%s]", expr)
end

function M.eigensystem(expr)
  return string.format("EigenSystem[%s]", expr) -- returns {vals, vecs}
end

-- Can add more advanced functions: JordanDecomposition, etc.

return M
