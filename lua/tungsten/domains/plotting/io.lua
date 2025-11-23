local lfs = require("lfs")
local path = require("pl.path")
local dir = require("pl.dir")
local error_handler = require("tungsten.util.error_handler")

local M = {}

local sequential_counters = {}
local fallback_counter = 0

local function find_latest_existing(dir_path, ext)
	if not dir_path or dir_path == "" then
		return nil
	end

	local pattern
	if ext and ext ~= "" then
		pattern = "^plot_(%d+)%." .. ext:gsub("(%p)", "%%%1") .. "$"
	else
		pattern = "^plot_(%d+)"
	end

	local max_index = 0

	local ok = pcall(function()
		for entry in lfs.dir(dir_path) do
			local number = entry:match(pattern)
			if number then
				local value = tonumber(number)
				if value and value > max_index then
					max_index = value
				end
			end
		end
	end)

	if not ok or max_index == 0 then
		return nil
	end

	return path.normpath(path.join(dir_path, string.format("plot_%03d.%s", max_index, ext or "pdf")))
end

local function determine_next_available(dir_path)
	local max_index = 0

	if not dir_path or dir_path == "" then
		return 1
	end

	local ok = pcall(function()
		for entry in lfs.dir(dir_path) do
			if entry ~= "." and entry ~= ".." then
				local number = entry:match("^plot_(%d+)")
				if number then
					local value = tonumber(number)
					if value and value > max_index then
						max_index = value
					end
				end
			end
		end
	end)

	if not ok then
		return 1
	end

	return max_index + 1
end

local function next_sequential_value(dir_path)
	if dir_path and dir_path ~= "" then
		local next_value = sequential_counters[dir_path]
		if not next_value then
			next_value = determine_next_available(dir_path)
		end
		sequential_counters[dir_path] = next_value + 1
		return next_value
	end

	fallback_counter = fallback_counter + 1
	return fallback_counter
end

function M.generate_filename(opts, context)
	opts = opts or {}
	context = context or {}
	local mode = opts.filename_mode or "sequential"

	if mode == "timestamp" then
		local stamp = os.date("%Y-%m-%d_%H-%M-%S")
		return "plot_" .. stamp
	end

	local seq = next_sequential_value(context.output_dir)
	return string.format("plot_%03d", seq)
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

	local had_counter = sequential_counters[output_dir] ~= nil

	local base = M.generate_filename(opts, {
		output_dir = output_dir,
		plot_data = plot_data,
	})
	local ext = opts.format or "pdf"
	local final_path = path.normpath(path.join(output_dir, base .. "." .. ext))

	local reused = false
	if lfs.attributes(final_path) then
		reused = true
	elseif not had_counter then
		local existing = find_latest_existing(output_dir, ext)
		if existing then
			final_path = existing
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
