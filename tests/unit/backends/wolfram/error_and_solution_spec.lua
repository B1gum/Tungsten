local mock_utils = require("tests.helpers.mock_utils")

describe("wolfram error and solution helpers", function()
	before_each(function()
		mock_utils.reset_modules({
			"tungsten.backends.wolfram.wolfram_error",
			"tungsten.backends.wolfram.wolfram_solution",
			"tungsten.backends.wolfram.wolfram_error",
			"tungsten.util.string",
		})
	end)

	it("parses different wolfram error formats", function()
		local parser = require("tungsten.backends.wolfram.wolfram_error")

		assert.is_nil(parser.parse_wolfram_error(""))
		assert.is_nil(parser.parse_wolfram_error({}))

		local err1 = parser.parse_wolfram_error("General::stop: message >>")
		assert.equals("General::stop: message >", err1)

		local err2 = parser.parse_wolfram_error('Message[Hold::tag, "oops"]')
		assert.equals("Hold::tag: oops", err2)
	end)

	it("formats solutions, errors, and fallbacks", function()
		mock_utils.mock_module("tungsten.backends.wolfram.wolfram_error", {
			parse_wolfram_error = function(output)
				if tostring(output):match("Message") then
					return "parsed error"
				end
				return nil
			end,
		})

		local solution = require("tungsten.backends.wolfram.wolfram_solution")

		local empty_result = solution.parse_wolfram_solution({}, { "x" })
		assert.is_false(empty_result.ok)
		assert.equals("No solution", empty_result.reason)

		local err = solution.parse_wolfram_solution({ 'Message[Oops::fail, "bad"]' }, { "x" })
		assert.is_false(err.ok)
		assert.equals("parsed error", err.reason)

		local mapped = solution.parse_wolfram_solution({ "{x -> 5, y -> 9}" }, { "x", "y" })
		assert.is_true(mapped.ok)
		assert.equals("x = 5, y = 9", mapped.formatted)

		local single = solution.parse_wolfram_solution("{{x -> 3}}", { "x" }, false)
		assert.equals("x = 3", single.formatted)

		local fallback = solution.parse_wolfram_solution("raw text", { "x" }, true)
		assert.is_true(fallback.ok)
		assert.equals("raw text", fallback.formatted)
	end)

	it("formats quantities with siunitx units", function()
		local solution = require("tungsten.backends.wolfram.wolfram_solution")

		local simple = solution.format_quantities('Quantity[3, "Meters"]')
		assert.equals("\\qty{3}{\\m}", simple)

		local composite =
			solution.format_quantities('\\qty{1}{\\kg} \\cdot \\qty{10}{\\m\\per\\s} = Quantity[10, "Newtons"*"Seconds"]')

		assert.equals("\\qty{1}{\\kg} \\cdot \\qty{10}{\\m\\per\\s} = \\qty{10}{\\newton.\\s}", composite)
	end)
end)
