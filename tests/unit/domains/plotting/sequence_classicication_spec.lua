local stub = require("luassert.stub")

describe("Sequence plot classification", function()
	local classification

	before_each(function()
		package.loaded["tungsten.domains.plotting.classification"] = nil
		package.loaded["tungsten.domains.plotting.free_vars"] = {
			find = function(node)
				local names = {}
				local function collect(n)
					if type(n) ~= "table" then
						return
					end
					if n.type == "function_call" then
						for _, arg in ipairs(n.args or {}) do
							collect(arg)
						end
						return
					end
					if n.type == "variable" then
						names[n.name] = true
					end
					for k, v in pairs(n) do
						if k ~= "type" and type(v) == "table" then
							if v.type then
								collect(v)
							else
								for _, child in pairs(v) do
									collect(child)
								end
							end
						end
					end
				end
				collect(node)
				local result = {}
				for name in pairs(names) do
					table.insert(result, name)
				end
				table.sort(result)
				return result
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

	it("throws an error when parametric and point series are mixed in advanced mode", function()
		local ast = require("tungsten.core.ast")
		local t = ast.create_variable_node("t")
		local sin_t = ast.create_function_call_node(ast.create_variable_node("sin"), { t })
		local cos_t = ast.create_function_call_node(ast.create_variable_node("cos"), { t })
		local seq = {
			type = "Sequence",
			nodes = {
				ast.create_point2_node(sin_t, cos_t),
				ast.create_point2_node(ast.create_number_node(1), ast.create_number_node(2)),
			},
		}

		local res, err = classification.analyze(seq, { mode = "advanced", form = "parametric" })
		assert.is_nil(res)
		assert.are.equal("E_MIXED_COORD_SYS", err.code)
	end)

	it("classifies a single Point3 node", function()
		local p = { type = "Point3", x = 1, y = 2, z = 3 }

		local res = classification.analyze(p)
		assert.are.same(1, #res.series)
		assert.are.same("points", res.series[1].kind)
		assert.are.same(p, res.series[1].points[1])
		assert.are.same(3, res.dim)
		assert.are.same("explicit", res.form)
	end)

	it("groups consecutive Point3 nodes into a single points series", function()
		local seq = {
			type = "Sequence",
			nodes = {
				{ type = "Point3", x = 1, y = 2, z = 3 },
				{ type = "Point3", x = 4, y = 5, z = 6 },
			},
		}

		local res = classification.analyze(seq)
		assert.are.same(1, #res.series)
		assert.are.same("points", res.series[1].kind)
		assert.are.equal(2, #res.series[1].points)
		assert.are.same(3, res.dim)
		assert.are.same("explicit", res.form)
	end)
end)
