local lfs = require("lfs")
local path = require("pl.path")
local dir = require("pl.dir")

local M = {}

local E_TEX_ROOT_NOT_FOUND = {
	code = "E_TEX_ROOT_NOT_FOUND",
	message = "TeX root file not found",
}

function M.find_tex_root(current_buf_path)
	if not current_buf_path or current_buf_path == "" then
		return nil, E_TEX_ROOT_NOT_FOUND
	end

	local current_dir = path.dirname(current_buf_path)

	local file = io.open(current_buf_path, "r")
	if file then
		local content = file:read("*a") or ""
		file:close()
		local magic = content:match("%%!TEX%s+root%s*=%s*([^\n\r]+)")
		if magic and magic ~= "" then
			magic = magic:gsub("^%s+", ""):gsub("%s+$", "")
			local root_path
			if path.isabs(magic) then
				root_path = path.normpath(magic)
			else
				root_path = path.normpath(path.join(current_dir, magic))
			end
			return root_path, nil
		end
		if content:find("\\documentclass") then
			return current_buf_path, nil
		end
	end

	local search_dir = current_dir
	while search_dir and search_dir ~= "" do
		for entry in lfs.dir(search_dir) do
			if entry:match("%.tex$") then
				local candidate = path.join(search_dir, entry)
				local f = io.open(candidate, "r")
				if f then
					local text = f:read("*a") or ""
					f:close()
					if text:find("\\documentclass") then
						return candidate, nil
					end
				end
			end
		end
		local parent = path.dirname(search_dir)
		if not parent or parent == search_dir then
			break
		end
		search_dir = parent
	end

	return nil, E_TEX_ROOT_NOT_FOUND
end

function M.get_output_directory(tex_root_path)
	if not tex_root_path or tex_root_path == "" then
		return nil, { code = "E_INVALID_PATH", message = "Invalid TeX root path" }
	end

	local base_dir = path.dirname(tex_root_path)
	local target_base

	local file = io.open(tex_root_path, "r")
	if file then
		local content = file:read("*a") or ""
		file:close()
		local gp_block = content:match("\\graphicspath%s*{(%b{})}")
		if gp_block then
			local first = gp_block:sub(2, -2)
			if first and first ~= "" then
				if path.isabs(first) then
					target_base = path.normpath(first)
				else
					target_base = path.normpath(path.join(base_dir, first))
				end
			end
		end
	end

	if not target_base or target_base == "" then
		target_base = base_dir
	end

	local final_dir = path.normpath(path.join(target_base, "tungsten_plots"))
	local ok, err = dir.makepath(final_dir)
	if not ok then
		return nil, err
	end
	return final_dir, nil
end

function M.ensure_output_path_exists(tex_root_path)
	local _, err = M.get_output_directory(tex_root_path)
	return err
end

return M
