local M = {}
local config = require("tungsten.config")

function M.build(classification, user_overrides)
	user_overrides = user_overrides or {}

	local defaults = (config.plotting or {})

	local opts = {
		dim = classification.dim,
		form = classification.form,
		backend = "wolfram",
		format = classification.dim == 2 and "pdf" or "png",
		grids = true,
		legend_auto = true,
		usetex = defaults.usetex or true,
		latex_engine = defaults.latex_engine or "pdflatex",
		latex_preamble = defaults.latex_preamble or "",
		outputmode = defaults.outputmode or "latex",
		filename_mode = defaults.filename_mode or "hash",
    viewer_cmd_pdf = defaults.viewer_cmd_pdf or (vim.fn.has("macunix") == 1 and "open" or "xdg-open"),
    viewer_cmd_png = defaults.viewer_cmd_png or (vim.fn.has("macunix") == 1 and "open" or "xdg-open"),
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
