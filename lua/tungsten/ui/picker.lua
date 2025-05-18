-- Returns a sorted table of Tungsten user‑commands, ready for Telescope.
local M = {}

function M.list()
  local cmds  = vim.api.nvim_get_commands({})
  local items = {}

  for name, meta in pairs(cmds) do
    if name:find("^Tungsten") then
      items[#items + 1] = {
        value   = name,
        display = meta.description or name,
        ordinal = meta.description or name,
      }
    end
  end

  table.sort(items, function(a, b)
    return a.display:lower() < b.display:lower()
  end)

  return items
end

return M

