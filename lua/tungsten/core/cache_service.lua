local config = require("tungsten.config")
local logger = require("tungsten.util.logger")
local state = require("tungsten.state")

local CacheService = {}

function CacheService.get_cache_key(code_string, numeric)
	return code_string .. (numeric and "::numeric" or "::symbolic")
end

function CacheService.should_use_cache()
	return (config.cache_enabled == nil) or (config.cache_enabled == true)
end

function CacheService.try_get(cache_key, use_cache, callback)
	if not use_cache then
		return false
	end

	local cached = state.cache:get(cache_key)
	if not cached then
		return false
	end

	logger.info("Tungsten", "Tungsten: Result from cache.")
	logger.debug("Tungsten Debug", "Tungsten Debug: Cache hit for key: " .. cache_key)
	vim.schedule(function()
		callback(cached, nil)
	end)
	return true
end

function CacheService.store(cache_key, value)
	state.cache:set(cache_key, value)
	logger.info("Tungsten Debug", "Tungsten: Result for key '" .. cache_key .. "' stored in cache.")
end

function CacheService.clear()
	state.cache:clear()
	logger.info("Tungsten", "Tungsten: Cache cleared.")
end

return CacheService
