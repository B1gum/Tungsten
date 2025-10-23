local M = {}

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

		local env = start_line_text:match("\\begin%s*{%s*([%w%*%-]+)%s*}")
		if env then
			add_closer("\\end{" .. env .. "}", make_env_finder(env))
		end

		if start_line_text:find("$$", 1, true) then
			add_closer("$$", make_plain_finder("$$"), 1)
		end
	end

	if not added["\\]"] then
		add_closer("\\]", make_plain_finder("\\]"))
	end

	if not added["$$"] then
		add_closer("$$", make_plain_finder("$$"))
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

return M
