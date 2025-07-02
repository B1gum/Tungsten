local M = {}

function M.notify_error(context, error_code)
  local message = string.format("Tungsten[%s] %s", tostring(context), tostring(error_code))
  if vim and vim.notify then
    vim.schedule(function()
      vim.notify(message, vim.log.levels.ERROR)
    end)
  else
    print(message)
  end
end

return M
