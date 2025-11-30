local plot_io = require("tungsten.domains.plotting.io")

local M = {}

function M.assign(output_dir, opts, metadata)
	opts = opts or {}
	metadata = metadata or {}

	local plot_data = {
		ast = metadata.ast or opts.ast,
		var_defs = metadata.var_defs or metadata.definitions or opts.definitions,
	}

	local out_path = plot_io.get_final_path(output_dir, opts, plot_data)
	if not out_path or out_path == "" then
		return nil, "Unable to determine output path"
	end

	opts.out_path = out_path
	opts.uses_graphicspath = metadata.uses_graphicspath
	opts.tex_root = metadata.tex_root

	return out_path, nil
end

return M
