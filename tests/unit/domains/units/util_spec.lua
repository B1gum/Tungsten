describe("domains.units.util", function()
	local util = require("tungsten.domains.units.util")

	describe("render_unit", function()
		it("renders prefixed base units with expanded names", function()
			local node = { type = "unit_component", name = "km" }

			assert.are.equal("Kilometers", util.render_unit(node))
		end)

		it("preserves base units without expanding them", function()
			local node = { type = "unit_component", name = "m" }

			assert.are.equal("m", util.render_unit(node))
		end)

		it("expands micro prefixes for symbols and letters", function()
			local letter_node = { type = "unit_component", name = "us" }
			local symbol_node = { type = "unit_component", name = "μs" }

			assert.are.equal("Microseconds", util.render_unit(letter_node))
			assert.are.equal("Microseconds", util.render_unit(symbol_node))
		end)

		it("leaves unknown prefixes or bases untouched", function()
			local unknown_prefix = { type = "unit_component", name = "xm" }
			local unknown_base = { type = "unit_component", name = "kxyz" }

			assert.are.equal("xm", util.render_unit(unknown_prefix))
			assert.are.equal("kxyz", util.render_unit(unknown_base))
		end)

		it("removes leading backslashes from unit names", function()
			local node = { type = "unit_component", name = "\\m" }

			assert.are.equal("m", util.render_unit(node))
		end)

		it("renders superscript nodes", function()
			local node = {
				type = "superscript",
				base = { type = "unit_component", name = "m" },
				exponent = { type = "number", value = 2 },
			}

			assert.are.equal("m^2", util.render_unit(node))
		end)

		it("renders binary nodes with multiplication and division", function()
			local multiply = {
				type = "binary",
				operator = "*",
				left = { type = "unit_component", name = "m" },
				right = { type = "unit_component", name = "s" },
			}
			local divide = {
				type = "binary",
				operator = "/",
				left = { type = "unit_component", name = "m" },
				right = { type = "unit_component", name = "s" },
			}

			assert.are.equal("m s", util.render_unit(multiply))
			assert.are.equal("m/s", util.render_unit(divide))
		end)

		it("renders numbers and returns empty string for unknown nodes", function()
			assert.are.equal("3.5", util.render_unit({ type = "number", value = 3.5 }))
			assert.are.equal("", util.render_unit({ type = "unknown" }))
			assert.are.equal("", util.render_unit(nil))
		end)
	end)
end)
