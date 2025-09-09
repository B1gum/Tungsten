local M = {}

local function version_at_least(found, required)
	local function split(v)
		local parts = {}
		for num in v:gmatch("%d+") do
			table.insert(parts, tonumber(num))
		end
		return parts
	end
	local f, r = split(found), split(required)
	local len = math.max(#f, #r)
	for i = 1, len do
		local fv, rv = f[i] or 0, r[i] or 0
		if fv > rv then
			return true
		elseif fv < rv then
			return false
		end
	end
	return true
end

local function evaluate_version(found, required)
	if not found or found == "" then
		return { ok = false, message = string.format("required %s+, found none", required) }
	end
	if version_at_least(found, required) then
		return { ok = true, version = found }
	end
	return { ok = false, message = string.format("required %s+, found %s", required, found) }
end

function M.check_dependencies()
	local report = {}

	report.wolframscript = evaluate_version(nil, "13.0")
	if vim.fn.executable("wolframscript") == 1 then
		local output = {}
		local job_id = vim.fn.jobstart({ "wolframscript", "-version" }, {
			stdout_buffered = true,
			on_stdout = function(_, data)
				for _, line in ipairs(data) do
					if line ~= "" then
						table.insert(output, line)
					end
				end
			end,
		})
		if job_id > 0 then
			vim.fn.jobwait({ job_id }, 5000)
			local version = table.concat(output, "\n"):match("%d+%.%d+%.?%d*")
			report.wolframscript = evaluate_version(version, "13.0")
		end
	end

	local python_cmd
	if vim.fn.executable("python3") == 1 then
		python_cmd = "python3"
	end

	report.python = evaluate_version(nil, "3.10")
	report.numpy = evaluate_version(nil, "1.23")
	report.sympy = evaluate_version(nil, "1.12")
	report.matplotlib = evaluate_version(nil, "3.6")

	if python_cmd then
		local stdout = {}
		local job_id = vim.fn.jobstart({
			python_cmd,
			"-c",
			[[import json,sys; import numpy, sympy, matplotlib; print(json.dumps({'python':sys.version,'numpy':numpy.__version__,'sympy':sympy.__version__,'matplotlib':matplotlib.__version__}))]],
		}, {
			stdout_buffered = true,
			on_stdout = function(_, data)
				for _, line in ipairs(data) do
					if line ~= "" then
						table.insert(stdout, line)
					end
				end
			end,
		})

		if job_id > 0 then
			vim.fn.jobwait({ job_id }, 10000)
			local ok, decoded = pcall(vim.fn.json_decode, table.concat(stdout, "\n"))
			if ok and type(decoded) == "table" then
				local py_ver = decoded.python:match("%d+%.%d+%.%d+") or decoded.python:match("%d+%.%d+")
				report.python = evaluate_version(py_ver, "3.10")
				report.numpy = evaluate_version(decoded.numpy, "1.23")
				report.sympy = evaluate_version(decoded.sympy, "1.12")
				report.matplotlib = evaluate_version(decoded.matplotlib, "3.6")
			else
				local py_output = {}
				local ver_id = vim.fn.jobstart({ python_cmd, "-V" }, {
					stdout_buffered = true,
					stderr_buffered = true,
					on_stdout = function(_, data)
						for _, line in ipairs(data) do
							if line ~= "" then
								table.insert(py_output, line)
							end
						end
					end,
					on_stderr = function(_, data)
						for _, line in ipairs(data) do
							if line ~= "" then
								table.insert(py_output, line)
							end
						end
					end,
				})
				if ver_id > 0 then
					vim.fn.jobwait({ ver_id }, 5000)
					local ver_str = table.concat(py_output, "\n")
					local py_ver = ver_str:match("%d+%.%d+%.%d+") or ver_str:match("%d+%.%d+")
					report.python = evaluate_version(py_ver, "3.10")
				end
			end
		end
	end

	return report
end

return M
