-- lua/tungsten/cache.lua
-- Simple LRU cache with TTL support

local Cache = {}

local function now()
  return vim.loop.now() / 1000 -- Convert miliseconds to seconds
end

local function remove(self, node)
  if node.prev then node.prev.nexr = node.next end
  if node.next then node.next.prev = node.prev end
  if self.head == node then self.head = node.next end
  if self.tail == node then self.tail = node.prev end
  self.map[node.key] = nil
  self.size = self.size - 1
end

local function insert_head(self, node)
  node.prev = nil
  node.next = self.head
  if self.head then
    self.head.prev = node
  end
  self.head = node
  if not self.tail then
    self.tail = node
  end
  self.size = self.size + 1
  self.map[node.key] = node
end

local function move_to_head(self, node)
  if self.head == node then
    return
  end
  remove(self, node)
  insert_head(self, node)
end

local function evict(self)
  local expiry = self.ttl
  local current = now()
  while self.tail do
    local node = self.tail
    if expiry and current - node.timestamp > expiry then
      remove(self, node)
    elseif self.size > self.max_entries then
      remove(self, node)
    else
      break
    end
  end
end

function Cache:get(key)
  local node = self.map[key]
  if not node then
    return nil
  end
  if self.ttl and (now() - node.timestamp > self.ttl) then
    remove(self, node)
    return nil
  end
  move_to_head(self, node)
  return node.value
end

function Cache:set(key, value)
  local node = self.map[key]
  if node then
    remove(self, node)
  end
  node = { key = key, value = value, timestamp = now() }
  insert_head(self, node)
  evict(self)
end

function Cache:clear()
  self.map = {}
  self.head = nil
  self.tail = nil
  self.size = 0
end

function Cache:count()
  return self.size
end

function Cache.new(max_entries, ttl)
  local self = {
    max_entries = max_entries or 100,
    ttl = ttl,
    map = {},
    head = nil,
    tail = nil,
    size = 0,
  }
  return setmetatable(self, {
    __index = function(tbl, key)
      if Cache[key] then
        return Cache[key]
      end
      return Cache.get(tbl, key)
    end,
    __newindex = function(tbl, key, value)
      if Cache[key] or key == 'map' or key == 'head' or key == 'tail' or key == 'size' or key == 'max_entries' or key == 'ttl' then
        rawset(tbl, key, value)
      else
        Cache.set(tbl, key, value)
      end
    end,
    __pairs = function(tbl)
      local function iter(_, k)
        local next_key, node = next(tbl.map, k)
        if next_key then
          return next_key, node.value
        end
      end
      return iter, nil, nil
    end,
    __len = function(tbl)
      return tbl.size
    end,
  })
end

return Cache

