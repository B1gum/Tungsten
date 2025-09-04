local M = {}

function M.check_dependencies()
	local report = {
		wolframscript = false,
		python = false,
		matplotlib = false,
		sympy = false,
	}

	if vim.fn.executable("wolframscript") == 1 then
		report.wolframscript = true
	end

	local python_cmd
	if vim.fn.executable("python3") == 1 then
		python_cmd = "python3"
	elseif vim.fn.executable("python") == 1 then
		python_cmd = "python"
	end

	if python_cmd then
		report.python = true

		local output = {}
		local job_id = vim.fn.jobstart({
			python_cmd,
			"-c",
			[[import importlib, json, sys; libs=['matplotlib','sympy'];
print(json.dumps({l: importlib.util.find_spec(l) is not None for l in libs}))]],
		}, {
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
			vim.fn.jobwait({ job_id }, 10000)
			local ok, decoded = pcall(vim.fn.json_decode, table.concat(output, "\n"))
			if ok and type(decoded) == "table" then
				report.matplotlib = decoded.matplotlib and true or false
				report.sympy = decoded.sympy and true or false
			end
		end
	end

	return report
end

return M
