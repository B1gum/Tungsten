-- lua/tungsten/domains/plotting/backends.lua
-- Utilities for selecting backends and checking plotting capabilities

local backend_capabilities = require("tungsten.backends.capabilities")
local logger = require("tungsten.util.logger")

local M = {}

function M.get_backend(name)
	return backend_capabilities[name]
end

function M.is_supported(backend_name, form, dim, opts)
	opts = opts or {}

	logger.debug("TungstenPlot", string.format("Backend Check: backend='%s', form='%s', dim=%s", backend_name, form, dim))

	local backend = M.get_backend(backend_name)
	if not backend then
		logger.debug("TungstenPlot", "Backend Check Failed: Backend definition not found")
		return false
	end

	local form_table = backend.supports[form]
	if not form_table or not form_table[dim] then
		logger.debug("TungstenPlot", string.format("Backend Check Failed: Form '%s' in dim %s not supported", form, dim))
		return false
	end

	if opts.points then
		local pt = backend.points
		if not (pt and pt[dim]) then
			logger.debug("TungstenPlot", "Backend Check Failed: Points not supported in this dim")
			return false
		end
	end

	if opts.inequalities then
		local ineq = backend.inequalities
		if not (ineq and ineq[dim]) then
			logger.debug("TungstenPlot", "Backend Check Failed: Inequalities not supported in this dim")
			return false
		end
	end

	if backend_name == "python" and form == "explicit" then
		local dep = opts.dependent_vars or {}
		for _, v in ipairs(dep) do
			if v == "x" then
				logger.debug("TungstenPlot", "Backend Check Failed: Python cannot plot x as dependent in explicit mode")
				return false
			end
			if dim == 3 and v == "y" then
				logger.debug("TungstenPlot", "Backend Check Failed: Python cannot plot y as dependent in 3D explicit mode")
				return false
			end
		end
	end

	logger.debug("TungstenPlot", "Backend Check Passed")
	return true
end

local function get_config()
	local ok, cfg = pcall(require, "tungsten.config")
	if ok and type(cfg) == "table" then
		return cfg
	end
	return { backend = "wolfram" }
end

function M.get_configured_backend_name()
	local cfg = get_config()
	return cfg.plotting.backend or cfg.backend or "wolfram"
end

function M.get_configured_backend()
	return M.get_backend(M.get_configured_backend_name())
end

return M
