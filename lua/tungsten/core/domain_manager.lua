local registry = require("tungsten.core.registry")
local logger = require("tungsten.util.logger")
local config = require("tungsten.config")

local M = {}

local function default_domains_dir()
	local source = debug.getinfo(1, "S").source:sub(2)
	local base = source:match("(.+)/core/domain_manager%.lua$")
	return base and (base .. "/domains") or "lua/tungsten/domains"
end

function M.discover_domains(dir, user_dir)
	dir = dir or default_domains_dir()
	local domains = {}
	local seen = {}

	local function scan(path)
		if not path then
			return
		end

		for name, typ in vim.fs.dir(path) do
			if typ == "directory" and not seen[name] then
				table.insert(domains, name)
				seen[name] = true
			end
		end
	end

	scan(dir)
	scan(user_dir)

	return domains
end

function M.validate_metadata(meta)
	if type(meta) ~= "table" then
		return false, "domain module must return a table"
	end
	if type(meta.name) ~= "string" then
		return false, "missing name"
	end
	if type(meta.grammar) ~= "table" then
		return false, "missing grammar table"
	end
	if type(meta.grammar.contributions) ~= "table" then
		return false, "grammar.contributions must be table"
	end
	if meta.commands ~= nil and type(meta.commands) ~= "table" then
		return false, "commands must be table or nil"
	end
	if meta.handlers ~= nil and type(meta.handlers) ~= "function" then
		return false, "handlers must be function or nil"
	end
	return true
end

local function register_domain(meta)
	registry.register_domain_metadata(meta.name, meta)
	for _, contrib in ipairs(meta.grammar.contributions) do
		local prio = contrib.priority or meta.priority or 0
		registry.register_grammar_contribution(meta.name, prio, contrib.name, contrib.pattern, contrib.category)
	end
	if type(meta.commands) == "table" then
		for _, cmd in ipairs(meta.commands) do
			registry.register_command(cmd)
		end
	elseif type(meta.commands) == "function" then
		pcall(meta.commands)
	end
end

function M.register_domain(name)
	local ok, mod = pcall(require, "tungsten.domains." .. name)
	if not ok then
		logger.notify(
			"DomainManager: failed to load domain " .. name .. ": " .. tostring(mod),
			logger.levels.ERROR,
			{ title = "Tungsten DomainManager" }
		)
		return nil, mod
	end
	local valid, err = M.validate_metadata(mod)
	if not valid then
		logger.notify(
			"DomainManager: invalid domain " .. name .. ": " .. tostring(err),
			logger.levels.ERROR,
			{ title = "Tungsten DomainManager" }
		)
		return nil, err
	end
	register_domain(mod)
	return mod
end

function M.setup()
	local registered = {}

	local function register_if_new(name)
		if not registered[name] then
			registered[name] = true
			M.register_domain(name)
		end
	end

	local names = {}
	if type(config.domains) == "table" then
		for _, n in ipairs(config.domains) do
			table.insert(names, n)
		end
	end

	local loaded = {}
	local function load_metadata(name)
		if loaded[name] ~= nil then
			return loaded[name]
		end
		local ok, mod = pcall(require, "tungsten.domains." .. name)
		if not ok then
			logger.notify(
				"DomainManager: failed to load domain " .. name .. ": " .. tostring(mod),
				logger.levels.ERROR,
				{ title = "Tungsten DomainManager" }
			)
			loaded[name] = false
			return nil
		end
		loaded[name] = mod
		return mod
	end

	local ordered = {}
	local visiting = {}
	local visited = {}

	local function visit(name)
		if visited[name] then
			return
		end
		if visiting[name] then
			logger.notify(
				"DomainManager: cyclic dependency involving " .. name,
				logger.levels.ERROR,
				{ title = "Tungsten DomainManager" }
			)
			return
		end
		visiting[name] = true
		local meta = load_metadata(name)
		if meta and type(meta.dependencies) == "table" then
			for _, dep in ipairs(meta.dependencies) do
				if not visited[dep] then
					visit(dep)
				end
			end
		end
		visiting[name] = nil
		visited[name] = true
		table.insert(ordered, name)
	end

	for _, name in ipairs(names) do
		visit(name)
	end

	for _, name in ipairs(ordered) do
		register_if_new(name)
	end
end

function M.reload(opts)
	registry.reset()
	require("tungsten.core.parser").reset_grammar()
	for name, _ in pairs(package.loaded) do
		if name:match("tungsten%.domains%.") then
			package.loaded[name] = nil
		end
	end
	M.setup(opts)
end

return M
