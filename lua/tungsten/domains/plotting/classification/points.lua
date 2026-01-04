local helpers = require("tungsten.domains.plotting.helpers")
local error_handler = require("tungsten.util.error_handler")
local util = require("tungsten.domains.plotting.classification.util")

local M = {}

function M.analyze_point2(point, opts)
	opts = opts or {}
	if opts.mode == "advanced" then
		if opts.form == "parametric" then
			local params = util.union_vars(util.find_free_variables(point.x), util.find_free_variables(point.y))
			if #params == 0 then
				return {
					dim = 2,
					form = "explicit",
					series = { { kind = "points", points = { point } } },
				}
			end
			local param = helpers.detect_point2_param(point)
			if not param then
				return nil,
					{
						code = error_handler.E_MIXED_COORD_SYS,
						message = "Use the same parameter in both coordinates before plotting parametric points.",
					}
			end
			return {
				dim = 2,
				form = "parametric",
				series = { { kind = "function", ast = point, independent_vars = params, dependent_vars = { "x", "y" } } },
			}
		elseif opts.form == "polar" then
			if not (point.y and (point.y.type == "variable" or point.y.type == "greek") and point.y.name == "theta") then
				return nil,
					{
						code = error_handler.E_MIXED_COORD_SYS,
						message = "Set the second coordinate to theta when plotting polar points.",
					}
			end
			local x_params = helpers.extract_param_names(point.x)
			for _, name in ipairs(x_params) do
				if name ~= "theta" then
					return nil,
						{
							code = error_handler.E_MIXED_COORD_SYS,
							message = "Use theta as the only parameter in polar coordinates.",
						}
				end
			end
			local params = util.union_vars(util.find_free_variables(point.x), util.find_free_variables(point.y))
			return {
				dim = 2,
				form = "polar",
				series = {
					{
						kind = "function",
						ast = point,
						independent_vars = params,
						dependent_vars = { "r" },
					},
				},
			}
		end
	end

	local params = util.union_vars(util.find_free_variables(point.x), util.find_free_variables(point.y))
	if #params == 1 then
		return {
			dim = 2,
			form = "parametric",
			series = {
				{
					kind = "function",
					ast = point,
					independent_vars = params,
					dependent_vars = { "x", "y" },
				},
			},
		}
	end

	return {
		dim = 2,
		form = "explicit",
		series = { { kind = "points", points = { point } } },
	}
end

function M.analyze_point3(point, opts)
	opts = opts or {}
	if opts.mode == "advanced" and opts.form == "parametric" then
		local x_params = helpers.extract_param_names(point.x)
		local y_params = helpers.extract_param_names(point.y)
		local z_params = helpers.extract_param_names(point.z)
		local param_names = util.union_vars(x_params, y_params, z_params)

		if #param_names == 0 then
			return {
				dim = 3,
				form = "explicit",
				series = { { kind = "points", points = { point } } },
			}
		end

		if #param_names > 2 then
			return nil,
				{
					code = error_handler.E_MIXED_COORD_SYS,
					message = "Limit 3D parametric points to one or two parameters before plotting.",
				}
		end
		local params = util.union_vars(
			util.find_free_variables(point.x),
			util.find_free_variables(point.y),
			util.find_free_variables(point.z)
		)
		return {
			dim = 3,
			form = "parametric",
			series = { { kind = "function", ast = point, independent_vars = params, dependent_vars = { "x", "y", "z" } } },
		}
	end

	local params = util.union_vars(
		util.find_free_variables(point.x),
		util.find_free_variables(point.y),
		util.find_free_variables(point.z)
	)
	if #params >= 1 and #params <= 2 then
		return {
			dim = 3,
			form = "parametric",
			series = {
				{
					kind = "function",
					ast = point,
					independent_vars = params,
					dependent_vars = { "x", "y", "z" },
				},
			},
		}
	end

	return {
		dim = 3,
		form = "explicit",
		series = { { kind = "points", points = { point } } },
	}
end

return M
