local error_handler = require("tungsten.util.error_handler")
local plot_io = require("tungsten.domains.plotting.io")

local M = {}

local function normalize_error(err, fallback_code)
	if err == nil then
		return nil
	end

	if type(err) == "table" then
		return err
	end

	local normalized = { code = fallback_code or error_handler.E_BAD_OPTS }
	if err ~= normalized.code then
		normalized.message = err
	end
	return normalized
end

function M.resolve_paths(bufnr)
	if not bufnr or bufnr == 0 then
		bufnr = vim.api.nvim_get_current_buf()
	end

	local buf_path = vim.api.nvim_buf_get_name(bufnr)
	local tex_root, tex_err = plot_io.find_tex_root(buf_path)
	if not tex_root then
		return nil, nil, nil, normalize_error(tex_err, error_handler.E_TEX_ROOT_NOT_FOUND)
	end

	local output_dir, output_err, uses_graphicspath = plot_io.get_output_directory(tex_root)
	if not output_dir then
		return nil, nil, nil, normalize_error(output_err, error_handler.E_BAD_OPTS)
	end

	return tex_root, output_dir, uses_graphicspath, nil
end

return M
