local M = {}

function M.wait_for(fn, timeout)
  timeout = timeout or 2000
  local start = vim.loop.now()
  vim.wait(timeout, function()
    return fn() or vim.loop.now() - start > timeout
  end, 10)
end

return M
