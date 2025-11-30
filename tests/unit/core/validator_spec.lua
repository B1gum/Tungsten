local validator = require("tungsten.core.validator")

local function tuple_node(meta)
	return { type = "Point2", _tuple_meta = meta }
end

describe("validator.validate tuple handling", function()
	it("rejects theta in non-polar tuples", function()
		local meta = {
			elements = {
				{ type = "number", value = 1 },
				{ type = "variable", name = "theta" },
			},
			input = "(1,theta)",
			parts = {
				{ start_pos = 1 },
				{ start_pos = 4 },
			},
		}

		local ok, msg, pos = validator.validate({ series = { tuple_node(meta) } }, { form = "cartesian" })

		assert.is_nil(ok)
		assert.are.equal(
			"Coordinate system mismatch: theta can unly be used with polar coordinates at line 1, column 4",
			msg
		)
		assert.are.equal(4, pos)
	end)

	it("rejects polar tuples with wrong arity", function()
		local meta = {
			elements = {
				{ type = "number", value = 1 },
				{ type = "variable", name = "theta" },
				{ type = "number", value = 3 },
			},
			input = "(1,theta,3)",
			parts = {
				{ start_pos = 1 },
				{ start_pos = 4 },
				{ start_pos = 10 },
			},
			opts = { form = "polar" },
		}

		local ok, msg, pos = validator.validate({ series = { tuple_node(meta) } }, { form = "polar" })

		assert.is_nil(ok)
		assert.are.equal("Polar typles support only 2D at line 1, column 10", msg)
		assert.are.equal(10, pos)
	end)

	it("rejects polar tuples without theta as second element", function()
		local meta = {
			elements = {
				{ type = "number", value = 1 },
				{ type = "variable", name = "phi" },
			},
			input = "(1,phi)",
			parts = {
				{ start_pos = 1 },
				{ start_pos = 4 },
			},
			opts = { form = "polar" },
		}

		local ok, msg, pos = validator.validate({ series = { tuple_node(meta) } }, { form = "polar" })

		assert.is_nil(ok)
		assert.are.equal("Polar tuples must have theta as second element at line 1, column 4", msg)
		assert.are.equal(4, pos)
	end)

	it("rejects polar tuples without r as a function of theta", function()
		local meta = {
			elements = {
				{ type = "variable", name = "r" },
				{ type = "variable", name = "theta" },
			},
			input = "(r,theta)",
			parts = {
				{ start_pos = 1 },
				{ start_pos = 3 },
			},
			opts = { form = "polar" },
		}

		local ok, msg, pos = validator.validate({ series = { tuple_node(meta) } }, { form = "polar" })

		assert.is_nil(ok)
		assert.are.equal("Polar tuples must define r as a function of θ at line 1, column 1", msg)
		assert.are.equal(1, pos)
	end)

	it("rejects parametric 3D tuples missing u and v parameters", function()
		local meta = {
			elements = {
				{ type = "variable", name = "u" },
				{ type = "variable", name = "v" },
				{ type = "variable", name = "w" },
			},
			input = "(u,v,w)",
			parts = {
				{ start_pos = 1 },
				{ start_pos = 3 },
				{ start_pos = 5 },
			},
			opts = { form = "parametric", mode = "advanced" },
		}

		local ok, msg, pos = validator.validate(
			{ series = { tuple_node(meta) } },
			{ form = "parametric", mode = "advanced" }
		)

		assert.is_nil(ok)
		assert.are.equal("Parametric 3D tuples must use parameters u and v at line 1, column 1", msg)
		assert.are.equal(1, pos)
	end)
end)

describe("validator.validate dimension and AST guards", function()
	it("rejects mixed 2D and 3D series", function()
		local series = {
			{ type = "Point2", _source = { input = "p2", start_pos = 1 } },
			{ type = "Point3", _source = { input = "p3", start_pos = 2 } },
		}

		local ok, msg, pos = validator.validate({ series = series })

		assert.is_nil(ok)
		assert.are.equal("Cannot mix 2D and 3D points in the same sequence or series at line 1, column 2", msg)
		assert.are.equal(2, pos)
	end)

	it("guards against nil or malformed AST roots", function()
		local ok1, msg1 = validator.validate(nil)
		assert.is_nil(ok1)
		assert.are.equal("Invalid AST", msg1)

		local ok2, msg2 = validator.validate({})
		assert.is_nil(ok2)
		assert.are.equal("Invalid AST", msg2)
	end)
end)
