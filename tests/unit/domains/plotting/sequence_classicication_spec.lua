local stub = require("luassert.stub")

describe("Sequence plot classification", function()
	local classification

	before_each(function()
		package.loaded["tungsten.domains.plotting.classification"] = nil
		package.loaded["tungsten.domains.plotting.free_vars"] = {
			find = function()
				return { "x" }
			end,
		}
		classification = require("tungsten.domains.plotting.classification")
	end)

	it("classifies a sequence of expressions into multiple series", function()
		local seq = {
			type = "Sequence",
			nodes = {
				{ type = "variable", name = "x" },
				{ type = "variable", name = "x" },
			},
		}

		local res = classification.analyze(seq)
		assert.are.same(2, #res.series)
		assert.are.same("function", res.series[1].kind)
		assert.are.same("function", res.series[2].kind)
		assert.are.same(2, res.dim)
		assert.are.same("explicit", res.form)
	end)

	it("groups consecutive Point nodes into a single points series", function()
		local seq = {
			type = "Sequence",
			nodes = {
				{ type = "Point2", x = 1, y = 2 },
				{ type = "Point2", x = 3, y = 4 },
				{ type = "Point2", x = 5, y = 6 },
			},
		}

		local res = classification.analyze(seq)
		assert.are.same(1, #res.series)
		assert.are.same("points", res.series[1].kind)
		assert.are.equal(3, #res.series[1].points)
		assert.are.same(2, res.dim)
		assert.are.same("explicit", res.form)
	end)
end)
