local function deep_copy(tbl)
	local copy = {}
	for key, value in pairs(tbl) do
		if type(value) == "table" then
			copy[key] = deep_copy(value)
		else
			copy[key] = value
		end
	end
	return copy
end

describe("tungsten.core.operators.with_symbols", function()
	local operators

	before_each(function()
		package.loaded["tungsten.core.operators"] = nil
		operators = require("tungsten.core.operators")
	end)

	it("copies precedence and associativity per operator", function()
		local extended = operators.with_symbols("symbol")

		for operator, attrs in pairs(operators.attributes) do
			assert.are_not.equal(attrs, extended[operator])
			assert.are.equal(attrs.prec, extended[operator].prec)
			assert.are.equal(attrs.assoc, extended[operator].assoc)
		end
	end)

	it("adds provided symbol key using the operator when no map provided", function()
		local extended = operators.with_symbols("render_symbol")

		for operator in pairs(operators.attributes) do
			assert.are.equal(operator, extended[operator].render_symbol)
		end
	end)

	it("uses a custom symbol map when provided", function()
		local custom_map = {
			["+"] = "plus",
			["-"] = "minus",
		}

		local extended = operators.with_symbols("display", custom_map)

		assert.are.equal("plus", extended["+"].display)
		assert.are.equal("minus", extended["-"].display)
		assert.are.equal("*", extended["*"].display)
	end)

	it("does not mutate base operator attributes", function()
		local original = deep_copy(operators.attributes)

		operators.with_symbols("symbol_key", { ["^"] = "caret" })

		assert.are.same(original, operators.attributes)
		for _, attrs in pairs(operators.attributes) do
			assert.is_nil(attrs.symbol_key)
		end
	end)
end)
