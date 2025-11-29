local logger = require("tungsten.util.logger")
local error_handler = require("tungsten.util.error_handler")
local health = require("tungsten.domains.plotting.health")

local M = {}

local dependency_report
local backend_dependency_status = {}
local dependency_waiters = {}
local dependency_check_in_flight = false
local dependency_failure_notified = {}

local backend_requirements = {
	wolfram = { "wolframscript" },
	python = { "python", "numpy", "sympy", "matplotlib" },
}

local function fmt_missing(name, info)
	info = info or {}
	if info.message then
		local required, found = info.message:match("required%s+([%d%.]+)%+, found%s+([%w%.]+)")
		if required and found then
			return string.format("%s %s < %s", name, found, required)
		end
	end
	return name
end

local function build_backend_dependency_status(report)
	local statuses = {}
	for backend, deps in pairs(backend_requirements) do
		local missing = {}
		for _, dep in ipairs(deps) do
			local info = report[dep]
			if not info or not info.ok then
				table.insert(missing, fmt_missing(dep, info))
			end
		end
		if #missing == 0 then
			statuses[backend] = { ok = true }
		else
			statuses[backend] = {
				ok = false,
				message = string.format("Missing dependencies (%s): %s", backend, table.concat(missing, ", ")),
			}
		end
	end
	return statuses
end

function M.get_backend_status(backend)
	backend = backend or "wolfram"
	local status = backend_dependency_status[backend]
	if status and not status.ok then
		return false, status.message
	end
	return true, nil
end

function M.notify_backend_failure(backend, message)
	backend = backend or "wolfram"
	if message and not dependency_failure_notified[backend] then
		logger.error("TungstenPlot", message)
	end
	if not dependency_failure_notified[backend] then
		error_handler.notify_error("TungstenPlot", error_handler.E_BACKEND_UNAVAILABLE, nil, nil, message)
		dependency_failure_notified[backend] = true
	end
end

local function resolve_dependency_waiters(report)
	dependency_report = report
	backend_dependency_status = build_backend_dependency_status(report)
	dependency_failure_notified = {}

	local waiters = dependency_waiters
	dependency_waiters = {}
	for _, waiter in ipairs(waiters) do
		waiter(report)
	end
end

function M.on_dependencies_ready(callback)
	if dependency_report ~= nil then
		callback(dependency_report)
		return
	end

	table.insert(dependency_waiters, callback)

	if dependency_check_in_flight then
		return
	end

	dependency_check_in_flight = true
	health.check_dependencies(function(report)
		dependency_check_in_flight = false
		resolve_dependency_waiters(report)
	end)
end

function M.has_dependency_report()
	return dependency_report ~= nil
end

function M.get_dependency_report()
	return dependency_report
end

function M.reset()
	dependency_report = nil
	backend_dependency_status = {}
	dependency_waiters = {}
	dependency_check_in_flight = false
	dependency_failure_notified = {}
end

return M
