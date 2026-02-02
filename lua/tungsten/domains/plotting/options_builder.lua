local M = {}
local config = require("tungsten.config")
local logger = require("tungsten.util.logger")
local style_parser = require("tungsten.domains.plotting.style_parser")

local RANGE_DEFAULTS = {
	["2:explicit"] = { xrange = "default_xrange" },
	["3:explicit"] = { xrange = "default_xrange", yrange = "default_yrange" },
	["2:implicit"] = { xrange = "default_xrange", yrange = "default_yrange" },
	["3:implicit"] = { xrange = "default_xrange", yrange = "default_yrange", zrange = "default_zrange" },
	["2:parametric"] = { t_range = "default_t_range" },
	["3:parametric"] = { u_range = "default_urange", v_range = "default_vrange" },
	["2:polar"] = { theta_range = "default_theta_range" },
}

local SAMPLE_GRID_DEFAULTS = {
	["2:explicit"] = { samples = 500 },
	["2:implicit"] = { grid_n = 200 },
	["2:parametric"] = { samples = 300 },
	["2:polar"] = { samples = 360 },
	["3:explicit"] = { grid_2d = { 100, 100 } },
	["3:parametric"] = { grid_3d = { 64, 64 } },
	["3:implicit"] = { vol_3d = { 30, 30, 30 }, plot_points = 30, max_recursion = 2 },
}

function M.build(classification, user_overrides)
	user_overrides = user_overrides or {}
	classification = vim.deepcopy(classification or {})

	if user_overrides.legend_position and user_overrides.legend_pos == nil then
		user_overrides.legend_pos = user_overrides.legend_position
	end

	if user_overrides.legend ~= nil and user_overrides.legend_auto == nil then
		local toggle = user_overrides.legend
		if type(toggle) == "string" then
			local lowered = toggle:lower()
			toggle = lowered == "on" or lowered == "true" or lowered == "yes"
		end
		user_overrides.legend_auto = toggle and true or false
	end

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
		usetex = get_default(defaults.usetex, true),
		latex_engine = get_default(defaults.latex_engine, "pdflatex"),
		latex_preamble = get_default(defaults.latex_preamble, ""),
		outputmode = get_default(defaults.outputmode, "latex"),
		filename_mode = get_default(defaults.filename_mode, "sequential"),
		viewer_cmd_pdf = get_default(defaults.viewer_cmd_pdf, "open"),
		viewer_cmd_png = get_default(defaults.viewer_cmd_png, "open"),
		crop = true,
		timeout_ms = get_default(defaults.timeout_ms, config.process_timeout_ms or config.timeout_ms or 30000),
		series = {},
	}

	if classification.legend_auto ~= nil then
		opts.legend_auto = classification.legend_auto
	end

	if opts.format == "png" then
		opts.dpi = 180
	end

	local classification_key = string.format("%s:%s", classification.dim, classification.form)

	local range_defaults = RANGE_DEFAULTS[classification_key]
	if range_defaults then
		for opt_key, defaults_key in pairs(range_defaults) do
			opts[opt_key] = defaults[defaults_key]
		end
	end

	local sample_defaults = SAMPLE_GRID_DEFAULTS[classification_key]
	if sample_defaults then
		for opt_key, value in pairs(sample_defaults) do
			opts[opt_key] = value
		end
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

	local src_series = classification.series or {}
	for i, s in ipairs(src_series) do
		opts.series[i] = {}
		for k, v in pairs(s) do
			opts.series[i][k] = v
		end
		local style = style_parser.parse(s.style_tokens or s.style)
		for k, v in pairs(style) do
			opts.series[i][k] = v
		end
	end

	for k, v in pairs(user_overrides) do
		opts[k] = v
	end

	return opts
end

return M
