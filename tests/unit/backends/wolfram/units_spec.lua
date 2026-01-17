local spy = require("luassert.spy")

local units_wolfram_handlers

describe("Tungsten Units Domain Wolfram Handlers", function()
	local handlers
	local mock_recur_render

	before_each(function()
		package.loaded["tungsten.backends.wolfram.domains.units"] = nil
		units_wolfram_handlers = require("tungsten.backends.wolfram.domains.units")
		handlers = units_wolfram_handlers.handlers

		mock_recur_render = spy.new(function(node)
			if not node then
				return ""
			end
			if node.type == "number" then
				return tostring(node.value)
			end
			return "rendered(" .. (node.name or node.type or "node") .. ")"
		end)
	end)

	it("renders Quantity with prefixed units", function()
		local node = {
			type = "quantity",
			value = { type = "number", value = 5 },
			unit = { type = "unit_component", name = "km" },
		}

		local result = handlers.quantity(node, mock_recur_render)

		assert.are.equal('Quantity[5, "Kilometers"]', result)
		assert.spy(mock_recur_render).was.called_with(node.value)
	end)

	it("renders Quantity with compound unit division", function()
		local node = {
			type = "quantity",
			value = { type = "number", value = 2 },
			unit = {
				type = "binary",
				operator = "/",
				left = { type = "unit_component", name = "m" },
				right = { type = "unit_component", name = "s" },
			},
		}

		local result = handlers.quantity(node, mock_recur_render)

		assert.are.equal('Quantity[2, "m/s"]', result)
		assert.spy(mock_recur_render).was.called_with(node.value)
	end)

	it("renders angle as angular degrees", function()
		local node = { type = "angle", value = { type = "number", value = 90 } }

		local result = handlers.angle(node, mock_recur_render)

		assert.are.equal('Quantity[90, "AngularDegrees"]', result)
		assert.spy(mock_recur_render).was.called_with(node.value)
	end)

	it("passes through num_cmd values", function()
		local node = { type = "num_cmd", value = { type = "number", value = 42 } }

		local result = handlers.num_cmd(node, mock_recur_render)

		assert.are.equal("42", result)
		assert.spy(mock_recur_render).was.called_with(node.value)
	end)
end)
