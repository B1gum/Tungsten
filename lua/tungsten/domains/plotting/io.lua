local error_handler = require("tungsten.util.error_handler")

local M = {}

local uv = vim.uv or vim.loop

local function path_join(...)
	return table.concat({ ... }, "/"):gsub("//+", "/")
end

local function path_norm(path)
	return vim.fs.normalize(path)
end

local function path_dirname(path)
	return vim.fs.dirname(path)
end

local function path_isabs(path)
	return path:sub(1, 1) == "/" or path:match("^%a:")
end

local function file_exists(path)
	local stat = uv.fs_stat(path)
	return stat ~= nil
end

local function scandir(path)
	local handle = uv.fs_scandir(path)
	if not handle then
		return function() end
	end
	return function()
		local name, _ = uv.fs_scandir_next(handle)
		return name
	end
end

local display_envs = {
	"align",
	"align*",
	"alignat",
	"alignat*",
	"flalign",
	"flalign*",
	"gather",
	"gather*",
	"equation",
	"equation*",
	"multline",
	"multline*",
	"displaymath",
	"eqnarray",
	"eqnarray*",
	"dmath",
}

local function escape_pattern(str)
	return (str:gsub("([^%w])", "%%%1"))
end

local function make_plain_finder(token)
	local token_len = #token
	return function(line, from)
		local start_idx = line:find(token, from, true)
		if start_idx then
			return start_idx, start_idx + token_len - 1
		end
	end
end

local function is_escaped(line, idx)
	local backslash_count = 0
	local pos = idx - 1
	while pos > 0 and line:sub(pos, pos) == "\\" do
		backslash_count = backslash_count + 1
		pos = pos - 1
	end
	return backslash_count % 2 == 1
end

local function make_single_dollar_finder()
	return function(line, from)
		local search_from = from or 1
		while true do
			local start_idx = line:find("$", search_from, true)
			if not start_idx then
				return nil
			end
			if not is_escaped(line, start_idx) then
				local next_char = line:sub(start_idx + 1, start_idx + 1)
				if next_char == "$" and not is_escaped(line, start_idx + 1) then
					search_from = start_idx + 2
				else
					return start_idx, start_idx
				end
			else
				search_from = start_idx + 1
			end
		end
	end
end

local function count_unmatched_single_dollars(line)
	if not line or line == "" then
		return 0
	end

	local count = 0
	local search_from = 1
	while true do
		local idx = line:find("$", search_from, true)
		if not idx then
			break
		end
		if not is_escaped(line, idx) then
			local next_char = line:sub(idx + 1, idx + 1)
			if next_char == "$" and not is_escaped(line, idx + 1) then
				search_from = idx + 2
			else
				count = count + 1
				search_from = idx + 1
			end
		else
			search_from = idx + 1
		end
	end

	return count % 2
end

local function make_env_finder(env)
	local plain = "\\end{" .. env .. "}"
	local pattern = "\\\\end%s*{%s*" .. escape_pattern(env) .. "%s*}"
	local plain_len = #plain
	return function(line, from)
		local start_idx = line:find(plain, from, true)
		if start_idx then
			return start_idx, start_idx + plain_len - 1
		end
		return line:find(pattern, from)
	end
end

local single_dollar_finder = make_single_dollar_finder()

local function build_closers(start_line_text)
	local closers = {}
	local added = {}

	local function add_closer(key, finder, skip)
		closers[#closers + 1] = { find = finder, remaining_skip = skip or 0 }
		added[key] = true
	end

	if start_line_text then
		if start_line_text:find("\\[", 1, true) then
			add_closer("\\]", make_plain_finder("\\]"))
		end

		if start_line_text:find("\\(", 1, true) then
			add_closer("\\)", make_plain_finder("\\)"))
		end

		local env = start_line_text:match("\\begin%s*{%s*([%w%*%-]+)%s*}")
		if env then
			add_closer("\\end{" .. env .. "}", make_env_finder(env))
		end

		if start_line_text:find("$$", 1, true) then
			add_closer("$$", make_plain_finder("$$"), 1)
		end

		local unmatched_inline_dollars = count_unmatched_single_dollars(start_line_text)
		if unmatched_inline_dollars > 0 then
			add_closer("$", single_dollar_finder, unmatched_inline_dollars)
		end
	end

	if not added["\\]"] then
		add_closer("\\]", make_plain_finder("\\]"))
	end

	if not added["\\)"] then
		add_closer("\\)", make_plain_finder("\\)"))
	end

	if not added["$$"] then
		add_closer("$$", make_plain_finder("$$"))
	end

	if not added["$"] then
		add_closer("$", single_dollar_finder)
	end

	for _, env in ipairs(display_envs) do
		local key = "\\end{" .. env .. "}"
		if not added[key] then
			add_closer(key, make_env_finder(env))
		end
	end

	return closers
end

function M.find_math_block_end(bufnr, start_line)
	bufnr = bufnr or 0
	start_line = math.max(start_line or 0, 0)

	local start_line_text = vim.api.nvim_buf_get_lines(bufnr, start_line, start_line + 1, false)[1]
	local closers = build_closers(start_line_text)
	local lines = vim.api.nvim_buf_get_lines(bufnr, start_line, -1, false)

	for offset, line in ipairs(lines) do
		for _, closer in ipairs(closers) do
			local search_from = 1
			while true do
				local start_idx, end_idx = closer.find(line, search_from)
				if not start_idx then
					break
				end
				if closer.remaining_skip > 0 then
					closer.remaining_skip = closer.remaining_skip - 1
					search_from = end_idx + 1
				else
					return start_line + offset - 1
				end
			end
		end
	end

	return nil
end

local sequential_counters = {}
local fallback_counter = 0

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
		for entry in scandir(dir_path) do
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

	return path_norm(path_join(dir_path, string.format("plot_%03d.%s", max_index, ext or "pdf")))
end

local function determine_next_available(dir_path)
	local max_index = 0

	if not dir_path or dir_path == "" then
		return 1
	end

	local ok = pcall(function()
		for entry in scandir(dir_path) do
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

	local current_dir = path_dirname(current_buf_path)

	local file = io.open(current_buf_path, "r")
	if file then
		local content = file:read("*a") or ""
		file:close()
		local magic = content:match("%%!TEX%s+root%s*=%s*([^\n\r]+)")
		if magic and magic ~= "" then
			magic = magic:gsub("^%s+", ""):gsub("%s+$", "")
			local root_path
			if path_isabs(magic) then
				root_path = path_norm(magic)
			else
				root_path = path_norm(path_join(current_dir, magic))
			end
			return root_path, nil
		end
		if content:find("\\documentclass") then
			return current_buf_path, nil
		end
	end

	local search_dir = current_dir
	while search_dir and search_dir ~= "" do
		for entry in scandir(search_dir) do
			if entry:match("%.tex$") then
				local candidate = path_join(search_dir, entry)
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
		local parent = path_dirname(search_dir)
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

	local base_dir = path_dirname(tex_root_path)
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
					local normalized = path_norm(first)
					if path_isabs(normalized) then
						target_base = normalized
					else
						target_base = path_norm(path_join(base_dir, normalized))
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

	local final_dir = path_norm(path_join(target_base, "tungsten_plots"))
	local ok = vim.fn.mkdir(final_dir, "p")
	if ok ~= 1 then
		return nil, "Failed to create directory: " .. final_dir
	end
	return final_dir, nil, used_graphicspath
end

function M.resolve_paths(bufnr)
	if not bufnr or bufnr == 0 then
		bufnr = vim.api.nvim_get_current_buf()
	end

	local buf_path = vim.api.nvim_buf_get_name(bufnr)
	local tex_root, tex_err = M.find_tex_root(buf_path)
	if not tex_root then
		return nil, nil, nil, normalize_error(tex_err, error_handler.E_TEX_ROOT_NOT_FOUND)
	end

	local output_dir, output_err, uses_graphicspath = M.get_output_directory(tex_root)
	if not output_dir then
		return nil, nil, nil, normalize_error(output_err, error_handler.E_BAD_OPTS)
	end

	return tex_root, output_dir, uses_graphicspath, nil
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
	local final_path = path_norm(path_join(output_dir, base .. "." .. ext))

	local reused = false
	if file_exists(final_path) then
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

function M.assign_output_path(opts, output_dir, uses_graphicspath, tex_root)
	opts = opts or {}

	local plot_data = {
		ast = opts.ast,
		var_defs = opts.definitions,
	}

	local final_path, reused = M.get_final_path(output_dir, opts, plot_data)
	if not final_path or final_path == "" then
		return nil, "Unable to determine output path"
	end

	opts.out_path = final_path
	opts.uses_graphicspath = uses_graphicspath
	opts.tex_root = tex_root

	return final_path, reused
end

return M
