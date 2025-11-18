local lfs = require("lfs")
local path = require("pl.path")
local dir = require("pl.dir")
local ast = require("tungsten.core.ast")
local error_handler = require("tungsten.util.error_handler")

local M = {}

local sequential_counter = 0

local function is_array(tbl)
	if type(tbl) ~= "table" then
		return false
	end
	local n = 0
	for k, _ in pairs(tbl) do
		if type(k) ~= "number" then
			return false
		end
		n = n + 1
	end
	return n == #tbl
end

local function serialize(value)
	local t = type(value)
	if t == "table" then
		if is_array(value) then
			local parts = {}
			for i = 1, #value do
				parts[#parts + 1] = serialize(value[i])
			end
			return "[" .. table.concat(parts, ",") .. "]"
		else
			local keys = {}
			for k in pairs(value) do
				if type(k) == "string" then
					keys[#keys + 1] = k
				end
			end
			table.sort(keys)
			local parts = {}
			for _, k in ipairs(keys) do
				parts[#parts + 1] = k .. "=" .. serialize(value[k])
			end
			return "{" .. table.concat(parts, ",") .. "}"
		end
	elseif t == "boolean" or t == "number" then
		return tostring(value)
	elseif t == "string" then
		return value
	end
	return ""
end

local function build_signature(opts, plot_data)
	opts = opts or {}
	plot_data = plot_data or {}
	local parts = {}

	if plot_data.ast then
		parts[#parts + 1] = ast.canonical(plot_data.ast)
	end

	if plot_data.variables then
		parts[#parts + 1] = serialize(plot_data.variables)
	elseif plot_data.var_defs then
		parts[#parts + 1] = serialize(plot_data.var_defs)
	end

	parts[#parts + 1] = tostring(opts.backend or "")
	parts[#parts + 1] = tostring(opts.format or "")
	parts[#parts + 1] = tostring(opts.form or "")
	parts[#parts + 1] = tostring(opts.dim or "")

	local filtered_opts = {}
	for k, v in pairs(opts) do
		if k ~= "filename_mode" then
			filtered_opts[k] = v
		end
	end
	parts[#parts + 1] = serialize(filtered_opts)

	return table.concat(parts, "|")
end

function M.generate_filename(opts, plot_data)
	opts = opts or {}
	local mode = opts.filename_mode or "hash"

	if mode == "sequential" then
		sequential_counter = sequential_counter + 1
		return string.format("plot_%03d", sequential_counter)
	elseif mode == "timestamp" then
		local stamp = os.date("%Y-%m-%d_%H-%M-%S")
		return "plot_" .. stamp
	else
		local signature = build_signature(opts, plot_data)
		local digest = vim.fn.sha256(signature)
		return "plot_" .. digest:sub(1, 12)
	end
end

local E_TEX_ROOT_NOT_FOUND = {
	code = error_handler.E_TEX_ROOT_NOT_FOUND,
	message = "TeX root file not found. Add a '%!TEX root = <main.tex>' magic comment to your file to help Tungsten locate the main document.",
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
		return nil, { code = error_handler.E_BAD_OPTS, message = "Invalid TeX root path" }
	end

	local base_dir = path.dirname(tex_root_path)
	local target_base
	local used_graphicspath = false

	local file = io.open(tex_root_path, "r")
	if file then
		local content = file:read("*a") or ""
		file:close()
		local gp_block = content:match("\\graphicspath%s*(%b{})")
		if gp_block then
			local inner = gp_block:sub(2, -2)
			for entry in inner:gmatch("(%b{})") do
				local first = entry:sub(2, -2)
				first = first:gsub("^%s+", ""):gsub("%s+$", "")
				if first ~= "" then
					local normalized = path.normpath(first)
					if path.isabs(normalized) then
						target_base = normalized
					else
						target_base = path.normpath(path.join(base_dir, normalized))
					end
					used_graphicspath = true
					break
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
	return final_dir, nil, used_graphicspath
end

function M.get_final_path(output_dir, opts, plot_data)
	opts = opts or {}
	plot_data = plot_data or {}

	local base = M.generate_filename(opts, plot_data)
	local ext = opts.format or "pdf"
	local final_path = path.normpath(path.join(output_dir, base .. "." .. ext))
	local reused = false

	if opts.filename_mode == "hash" then
		local attr = lfs.attributes(final_path)
		if attr and attr.mode == "file" then
			reused = true
		end
	end

	return final_path, reused
end

function M.write_atomically(final_path, image_data)
	local tmp_path = final_path .. ".tmp"
	local file, err = io.open(tmp_path, "wb")
	if not file then
		return nil, err
	end
	local ok, write_err = file:write(image_data)
	file:close()
	if not ok then
		os.remove(tmp_path)
		return nil, write_err
	end
	local ok_rename, rename_err = os.rename(tmp_path, final_path)
	if not ok_rename then
		os.remove(tmp_path)
		error(rename_err)
	end
	return true
end

function M.ensure_output_path_exists(tex_root_path)
	local _, err = M.get_output_directory(tex_root_path)
	return err
end

return M
