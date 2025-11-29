local error_handler = require("tungsten.util.error_handler")
local PlotBaseBackend = {}

function PlotBaseBackend.normalize_out_path(opts)
	if not opts then
		return
	end

	local out_path = opts.out_path
	if out_path and out_path ~= "" and not out_path:match("%.%w+$") then
		opts.out_path = out_path .. "." .. (opts.format or "png")
	end
end

function PlotBaseBackend.prepare_opts(opts, callback)
	assert(type(callback) == "function", "plot async expects a callback")

	opts = opts or {}
	PlotBaseBackend.normalize_out_path(opts)

	if not opts.out_path or opts.out_path == "" then
		return nil, {
			code = error_handler.E_BAD_OPTS,
			message = "Missing out_path",
		}
	end

	return opts, nil
end

return PlotBaseBackend
