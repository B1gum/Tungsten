local cache_module = require("tungsten.cache")

describe("tungsten.cache", function()
	local original_now
	local current

	local function set_now(ms)
		current = ms
		vim.loop.now = function()
			return current
		end
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
		cache:set("a", 1)
		cache:set("b", 2)
		cache:set("c", 3)
		assert.are.equal(3, cache:count())
		assert.are.equal(1, cache:get("a"))
		assert.are.equal(2, cache:get("b"))
		assert.are.equal(3, cache:get("c"))
	end)

	it("evicts least recently used when capacity exceeded", function()
		local cache = cache_module.new(2, nil)
		cache:set("a", "A")
		cache:set("b", "B")
		cache:set("c", "C")
		assert.is_nil(cache:get("a"))
		assert.are.equal("B", cache:get("b"))
		assert.are.equal("C", cache:get("c"))
	end)

	it("updates LRU on access", function()
		local cache = cache_module.new(2, nil)
		cache:set("a", "A")
		cache:set("b", "B")
		local _ = cache:get("a")
		cache:set("c", "C")
		assert.is_nil(cache:get("b"))
		assert.are.equal("A", cache:get("a"))
		assert.are.equal("C", cache:get("c"))
	end)

	it("expires entries older than ttl", function()
		local cache = cache_module.new(2, 5)
		cache:set("a", "A")
		set_now(6000)
		assert.is_nil(cache:get("a"))
		assert.are.equal(0, cache:count())
	end)

	it("maintains list integrity when removing a middle entry", function()
		local cache = cache_module.new(5, nil)
		cache:set("a", 1)
		cache:set("b", 2)
		cache:set("c", 3)

		cache:set("b", 22)

		assert.are.equal(3, cache:count())
		assert.are.equal("b", cache.head.key)
		assert.are.equal("a", cache.tail.key)
		assert.are.equal("c", cache.head.next.key)
		assert.are.same(cache.head, cache.head.next.prev)
		assert.are.same(cache.head.next, cache.tail.prev)
	end)
end)
