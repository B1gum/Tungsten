local M = {}
local config = require("tungsten.config")

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

  local defaults = (config.plotting or {})

  if classification.dim == 2 and classification.form == "explicit" then
    opts.xrange = defaults.default_xrange
  elseif classification.dim == 3 and classification.form == "explicit" then
    opts.xrange = defaults.default_xrange
    opts.yrange = defaults.default_yrange
  elseif classification.dim == 2 and classification.form == "implicit" then
    opts.xrange = defaults.default_xrange
    opts.yrange = defaults.default_yrange
  elseif classification.dim == 3 and classification.form == "implicit" then
    opts.xrange = defaults.default_xrange
    opts.yrange = defaults.default_yrange
    opts.zrange = defaults.default_zrange
  elseif classification.dim == 2 and classification.form == "parametric" then
    opts.t_range = defaults.default_t_range
  elseif classification.dim == 3 and classification.form == "parametric" then
    opts.u_range = defaults.default_urange
    opts.v_range = defaults.default_vrange
  elseif classification.dim == 2 and classification.form == "polar" then
    opts.theta_range = defaults.default_theta_range
  end

  for k, v in pairs(user_overrides) do
    opts[k] = v
  end

  return opts
end

return M
