--------------------------------------------------------------------------------
-- cache.lua
-- Very basic in-memory cache for tungsten computations
-- If you want persistence, you can store to file or DB too.
--------------------------------------------------------------------------------

local M = {}

-- A simple Lua table as our in-memory store:
local store = {}

-- Retrieve a cached value by key (string).
function M.get(key)
  return store[key]
end

-- Store a value under key (string).
function M.set(key, value)
  store[key] = value
end

-- Optionally, clear the cache
function M.clear()
  store = {}
end

return M
