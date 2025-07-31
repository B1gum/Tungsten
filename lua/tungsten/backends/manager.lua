local M = {}

local registry = {}
local active_instance

function M.register(name, module)
	if type(name) ~= "string" then
		error("Backend name must be a string", 2)
	end
	if module == nil then
		error("Backend module is nil", 2)
	end
	registry[name] = module
end

function M.activate(name, opts)
	local mod = registry[name]
	if not mod then
		return nil, string.format("Backend '%s' not registered", tostring(name))
	end

	local instance
	if type(mod) == "table" then
		if type(mod.activate) == "function" then
			instance = mod.activate(opts)
			if instance == nil then
				instance = mod
			end
		elseif type(mod.new) == "function" then
			instance = mod.new(opts)
		elseif type(mod.setup) == "function" then
			mod.setup(opts)
			instance = mod
		else
			instance = mod
		end
	elseif type(mod) == "function" then
		instance = mod(opts)
	else
		instance = mod
	end

	active_instance = instance

	return instance
end

function M.current()
	return active_instance
end

return M
