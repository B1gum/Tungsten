local cache_module = require 'tungsten.cache'

describe("tungsten.cache", function()
  local original_now
  local current

  local function set_now(ms)
    current = ms
    vim.loop.now = function() return current end
  end

  before_each(function()
    original_now = vim.loop.now
    set_now(0)
  end)

  after_each(function()
    vim.loop.now = original_now
  end)

  it("stores entries without eviction under limit", function()
    local cache = cache_module.new(5, nil)
    cache["a"] = 1
    cache["b"] = 2
    cache["c"] = 3
    assert.are.equal(3, cache:count())
    assert.are.equal(1, cache["a"])
    assert.are.equal(2, cache["b"])
    assert.are.equal(3, cache["c"])
  end)

  it("evicts least recently used when capacity exceeded", function()
    local cache = cache_module.new(2, nil)
    cache["a"] = "A"
    cache["b"] = "B"
    cache["c"] = "C"
    assert.is_nil(cache["a"])
    assert.are.equal("B", cache["b"])
    assert.are.equal("C", cache["c"])
  end)

  it("updates LRU on access", function()
    local cache = cache_module.new(2, nil)
    cache["a"] = "A"
    cache["b"] = "B"
    local _ = cache["a"]
    cache["c"] = "C"
    assert.is_nil(cache["b"])
    assert.are.equal("A", cache["a"])
    assert.are.equal("C", cache["c"])
  end)

  it("expires entries older than ttl", function()
    local cache = cache_module.new(2, 5)
    cache["a"] = "A"
    set_now(6000)
    assert.is_nil(cache["a"])
    assert.are.equal(0, cache:count())
  end)

  it("maintains list integrity when removing a middle entry", function()
    local cache = cache_module.new(5, nil)
    cache["a"] = 1
    cache["b"] = 2
    cache["c"] = 3

    cache["b"] = 22

    assert.are.equal(3, cache:count())
    assert.are.equal("b", cache.head.key)
    assert.are.equal("a", cache.tail.key)
    assert.are.equal("c", cache.head.next.key)
    assert.are.same(cache.head, cache.head.next.prev)
    assert.are.same(cache.head.next, cache.tail.prev)
  end)
end)

