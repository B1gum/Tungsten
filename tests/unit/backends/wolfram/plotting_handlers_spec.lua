local plotting_handlers = require("tungsten.backends.wolfram.domains.plotting_handlers")

describe("Wolfram plotting handlers", function()
	local handlers = plotting_handlers.handlers

	local function render_value(node)
		if node.fail then
			return { error = "render failed" }
		end
		return node.value
	end

	it("renders Sequence nodes from a nodes array", function()
		local node = { nodes = { { value = "a" }, { value = "b" } } }
		assert.are.equal("Sequence[a, b]", handlers.Sequence(node, render_value))
	end)

	it("renders Sequence nodes from indexed entries", function()
		local node = { { value = "x" }, { value = "y" } }
		assert.are.equal("Sequence[x, y]", handlers.Sequence(node, render_value))
	end)

	it("renders empty Sequence nodes", function()
		local node = { nodes = {} }
		assert.are.equal("Sequence[]", handlers.Sequence(node, render_value))
	end)

	it("propagates Sequence rendering errors", function()
		local err = handlers.Sequence({ nodes = { { value = "ok" }, { fail = true } } }, render_value)
		assert.are.same({ error = "render failed" }, err)
	end)

	it("renders Equality nodes", function()
		local node = { lhs = { value = "x" }, rhs = { value = "y" } }
		assert.are.equal("(x) == (y)", handlers.Equality(node, render_value))
	end)

	it("propagates Equality rendering errors", function()
		local err = handlers.Equality({ lhs = { value = "x" }, rhs = { fail = true } }, render_value)
		assert.are.same({ error = "render failed" }, err)
	end)

	it("renders Inequality nodes with unicode operators", function()
		local node = { lhs = { value = "x" }, rhs = { value = "y" }, op = "≤" }
		assert.are.equal("(x) <= (y)", handlers.Inequality(node, render_value))
	end)

	it("renders Inequality nodes with default operators", function()
		local node = { lhs = { value = "x" }, rhs = { value = "y" } }
		assert.are.equal("(x) < (y)", handlers.Inequality(node, render_value))
	end)

	it("renders Point nodes", function()
		local node = { x = { value = "1" }, y = { value = "2" } }
		assert.are.equal("Point[{1, 2}]", handlers.Point2(node, render_value))
	end)

	it("propagates Point rendering errors", function()
		local err = handlers.Point3({ x = { value = "1" }, y = { fail = true }, z = { value = "3" } }, render_value)
		assert.are.same({ error = "render failed" }, err)
	end)

	it("renders Parametric nodes", function()
		local node = { x = { value = "t" }, y = { value = "t^2" }, z = { value = "t^3" } }
		assert.are.equal("{t, t^2, t^3}", handlers.Parametric3D(node, render_value))
	end)

	it("renders Polar2D nodes", function()
		local node = { r = { value = "r" } }
		assert.are.equal("r", handlers.Polar2D(node, render_value))
	end)

	it("returns zero when Polar2D radius is missing", function()
		assert.are.equal("0", handlers.Polar2D({}, render_value))
	end)

	it("propagates Polar2D rendering errors", function()
		local err = handlers.Polar2D({ r = { fail = true } }, render_value)
		assert.are.same({ error = "render failed" }, err)
	end)
end)
