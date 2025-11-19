local M = {}

local current_check

local function run_system(cmd, opts, on_exit)
	opts = opts or {}
	opts.text = true

	local function invoke_callback(obj)
		if on_exit then
			if vim.in_fast_event() then
				vim.schedule(function()
					on_exit(obj)
				end)
			else
				on_exit(obj)
			end
		end
	end

	local ok, handle = pcall(vim.system, cmd, opts, function(obj)
		invoke_callback(obj)
	end)

	if not ok then
		invoke_callback({ code = -1, stdout = "", stderr = tostring(handle or "") })
		return nil
	end

	return handle
end

local function wait_group(on_complete)
	local pending = 0
	local completed = false

	local function maybe_finish()
		if not completed and pending == 0 then
			completed = true
			vim.schedule(function()
				on_complete()
			end)
		end
	end

	local function register()
		if completed then
			return function() end
		end
		pending = pending + 1
		local done = false
		return function()
			if done then
				return
			end
			done = true
			pending = pending - 1
			maybe_finish()
		end
	end

	return register, maybe_finish
end

function M.version_at_least(found, required)
	local function parse(v)
		local main, pre = v:match("^([0-9]+%.[0-9]+%.[0-9]+)(.*)$")
		if not main then
			main, pre = v:match("^([0-9]+%.[0-9]+)(.*)$")
			main = main .. ".0"
		end
		local nums = {}
		for num in main:gmatch("%d+") do
			table.insert(nums, tonumber(num))
		end
		pre = pre or ""
		if pre ~= "" then
			pre = pre:gsub("^[-.]", "")
			local tag, num = pre:match("^(%a+)(%d*)$")
			return nums, tag, tonumber(num) or 0
		end
		return nums, nil, 0
	end

	local pre_weight = { dev = 0, rc = 1 }
	local function weight(tag)
		if not tag then
			return 2
		end
		return pre_weight[tag] or 0
	end

	local fnums, ftag, fpre = parse(found)
	local rnums, rtag, rpre = parse(required)
	local len = math.max(#fnums, #rnums)
	for i = 1, len do
		local fv, rv = fnums[i] or 0, rnums[i] or 0
		if fv > rv then
			return true
		elseif fv < rv then
			return false
		end
	end

	local fw, rw = weight(ftag), weight(rtag)
	if fw > rw then
		return true
	elseif fw < rw then
		return false
	end

	if fw < 2 then
		return fpre >= rpre
	end
	return true
end

local function evaluate_version(found, required)
	if not found or found == "" then
		return { ok = false, message = string.format("required %s+, found none", required) }
	end
	if M.version_at_least(found, required) then
		return { ok = true, version = found }
	end
	return { ok = false, message = string.format("required %s+, found %s", required, found) }
end

local function start_check(callback)
	local report = {}

	report.wolframscript = evaluate_version(nil, "1.10.0")
	report.python = evaluate_version(nil, "3.10")
	report.numpy = evaluate_version(nil, "1.23")
	report.sympy = evaluate_version(nil, "1.12")
	report.matplotlib = evaluate_version(nil, "3.6")

	local register, finalize = wait_group(function()
		callback(report)
	end)

	local function complete_python_check()
		local done = register()
		done()
	end

	if vim.fn.executable("wolframscript") == 1 then
		local finish = register()
		run_system({ "wolframscript", "-version" }, {}, function(obj)
			if obj.code == 0 then
				local version = (obj.stdout or ""):match("%d+%.%d+%.?%d*")
				report.wolframscript = evaluate_version(version, "1.10.0")
			end
			finish()
		end)
	end

	local python_cmd
	if vim.fn.executable("python3") == 1 then
		python_cmd = "python3"
	end

	if python_cmd then
		local finish_python = register()
		run_system({
			python_cmd,
			"-c",
			[[import os; os.environ["MPLBACKEND"]="Agg"; import json,sys; import numpy, sympy; import matplotlib; matplotlib.use('Agg'); print(json.dumps({'python':sys.version,'numpy':numpy.__version__,'sympy':sympy.__version__,'matplotlib':matplotlib.__version__}))]],
		}, { env = { MPLBACKEND = "Agg" } }, function(obj)
			local ok, decoded
			if obj.code == 0 then
				ok, decoded = pcall(vim.json.decode, obj.stdout or "")
			end

			if ok and type(decoded) == "table" then
				local py_ver = decoded.python:match("%d+%.%d+%.%d+") or decoded.python:match("%d+%.%d+")
				report.python = evaluate_version(py_ver, "3.10")
				report.numpy = evaluate_version(decoded.numpy, "1.23")
				report.sympy = evaluate_version(decoded.sympy, "1.12")
				report.matplotlib = evaluate_version(decoded.matplotlib, "3.6")
				finish_python()
				return
			end

			run_system({ python_cmd, "-V" }, {}, function(version_obj)
				if version_obj.code == 0 then
					local ver_str = version_obj.stdout ~= "" and version_obj.stdout or version_obj.stderr or ""
					local py_ver = ver_str:match("%d+%.%d+%.%d+") or ver_str:match("%d+%.%d+")
					report.python = evaluate_version(py_ver, "3.10")
				end
				finish_python()
			end)
		end)
	else
		complete_python_check()
	end

	finalize()
end

function M.check_dependencies(callback)
	callback = callback or function() end

	if current_check then
		if current_check.resolved then
			callback(current_check.report)
		else
			table.insert(current_check.callbacks, callback)
		end
		return
	end

	current_check = { callbacks = { callback }, resolved = false }

	start_check(function(report)
		current_check.resolved = true
		current_check.report = report
		local listeners = current_check.callbacks
		current_check.callbacks = {}
		for _, cb in ipairs(listeners) do
			cb(report)
		end
	end)
end

function M.reset_cache()
	current_check = nil
end

return M
