local classification = require("tungsten.domains.plotting.classification")
local error_handler = require("tungsten.util.error_handler")

local M = {}

function M.merge(nodes, opts)
	local combined = { series = {} }
	for _, node in ipairs(nodes) do
		local res, err = classification.analyze(node, opts or { simple_mode = true, mode = "simple" })
		if not res then
			return nil, err
		end

		if combined.dim and res.dim and combined.dim ~= res.dim then
			return nil,
				{
					code = error_handler.E_UNSUPPORTED_DIM,
					message = "Select expressions of the same dimension before plotting.",
				}
		end

		if combined.form and res.form and combined.form ~= res.form then
			local compatible = false
			if
				(combined.form == "explicit" and res.form == "implicit")
				or (combined.form == "implicit" and res.form == "explicit")
			then
				compatible = true
			end

			if not compatible then
				return nil,
					{
						code = error_handler.E_MIXED_COORD_SYS,
						message = "Use the same coordinate system for all expressions before plotting.",
					}
			end
		end

		for key, value in pairs(res) do
			if key == "series" then
				for _, series_entry in ipairs(value or {}) do
					combined.series[#combined.series + 1] = vim.deepcopy(series_entry)
				end
			elseif combined[key] == nil and value ~= nil then
				combined[key] = value
			end
		end

		if combined.form == "explicit" and res.form == "implicit" then
			combined.form = "implicit"
		end
	end

	if not combined.dim or not combined.form or #combined.series == 0 then
		return nil,
			{
				code = error_handler.E_NO_PLOTTABLE_SERIES,
				message = "Select an expression with a plottable series so Tungsten can detect the dimension and coordinate form.",
			}
	end

	return combined
end

return M
