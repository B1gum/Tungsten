local M = {}

function M.build(classification, user_overrides)
  user_overrides = user_overrides or {}

  local opts = {
    dim = classification.dim,
    form = classification.form,
    backend = "wolfram",
    format = classification.dim == 2 and "pdf" or "png",
    grids = true,
    legend_auto = true,
    usetex = true,
    crop = true,
    timeout_ms = 30000,
    series = {},
  }

  if opts.format == "png" then
    opts.dpi = 180
  end

  for k, v in pairs(user_overrides) do
    opts[k] = v
  end

  return opts
end

return M
