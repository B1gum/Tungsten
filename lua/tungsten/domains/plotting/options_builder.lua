local M = {}
local config = require("tungsten.config")
local logger = require("tungsten.util.logger")

function M.build(classification, user_overrides)
	user_overrides = user_overrides or {}

	local defaults = (config.plotting or {})

	local function get_default(val, fallback)
		if val == nil then
			return fallback
		end
		return val
	end

	local backend = user_overrides.backend or defaults.backend or "wolfram"

	if backend == "python" and classification.dim == 3 and classification.form == "explicit" then
		local series = classification.series or {}
		local downgrade = true
		for _, s in ipairs(series) do
			local dep = s.dependent_vars or {}
			local indep = s.independent_vars or {}
			local has_z = false
			for _, v in ipairs(dep) do
				if v == "z" then
					has_z = true
					break
				end
			end
			if not has_z or #indep >= 2 then
				downgrade = false
				break
			end
		end
		if downgrade then
      local original_dep = {}
      for i, s in ipairs(series) do
        original_dep[i] = {}
        for j, v in ipairs(s.dependent_vars or {}) do
          original_dep[i][j] = v
        end
      end
			classification.dim = 2
      for i, s in ipairs(series) do
        s.dependent_vars = original_dep[i]
			end
			logger.warn("TungstenPlot", "Downgrading 3D explicit plot to 2D explicit for python backend")
		end
	end

	local opts = {
		dim = classification.dim,
		form = classification.form,
		backend = backend,
		format = classification.dim == 2 and "pdf" or "png",
		grids = true,
		legend_auto = true,
		usetex = get_default(defaults.usetex, true),
		latex_engine = get_default(defaults.latex_engine, "pdflatex"),
		latex_preamble = get_default(defaults.latex_preamble, ""),
		outputmode = get_default(defaults.outputmode, "latex"),
		filename_mode = get_default(defaults.filename_mode, "hash"),
		viewer_cmd_pdf = get_default(defaults.viewer_cmd_pdf, "open"),
		viewer_cmd_png = get_default(defaults.viewer_cmd_png, "open"),
		crop = true,
		timeout_ms = 30000,
		series = {},
	}

	if opts.format == "png" then
		opts.dpi = 180
	end

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

	if classification.dim == 2 and classification.form == "explicit" then
		opts.samples = 500
	elseif classification.dim == 2 and classification.form == "implicit" then
		opts.grid_n = 200
	elseif classification.dim == 2 and classification.form == "parametric" then
		opts.samples = 300
	elseif classification.dim == 2 and classification.form == "polar" then
		opts.samples = 360
	elseif classification.dim == 3 and classification.form == "explicit" then
		opts.grid_2d = { 100, 100 }
	elseif classification.dim == 3 and classification.form == "parametric" then
		opts.grid_3d = { 64, 64 }
	elseif classification.dim == 3 and classification.form == "implicit" then
		opts.vol_3d = { 30, 30, 30 }
	end

	if classification.dim == 2 and classification.form == "explicit" then
		opts.figsize_in = { 6, 4 }
		opts.aspect = "auto"
	else
		opts.figsize_in = { 6, 6 }
		opts.aspect = "equal"
	end

	if classification.dim == 3 then
		opts.view_elev = 30
		opts.view_azim = -60
	end

	opts.colormap = "viridis"
	opts.colorbar = false
	opts.bg_color = "white"

	for k, v in pairs(user_overrides) do
		opts[k] = v
	end

	for k, v in pairs(user_overrides) do
		opts[k] = v
	end

	return opts
end

return M
