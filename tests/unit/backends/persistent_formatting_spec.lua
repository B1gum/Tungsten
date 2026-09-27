local python = require("tungsten.backends.python.executor")
local wolfram = require("tungsten.backends.wolfram.executor")

describe("Backend Persistence Formatting", function()
	describe("Python", function()
		it("generates correct init code", function()
			local init = python.get_persistent_init()
			assert.matches("import sympy", init)
			assert.matches("sys.ps1=''", init)
		end)

		it("formats input to print latex and delimiter", function()
			local code = "1+1"
			local delimiter = "END"
			local result = python.format_persistent_input(code, delimiter)

			assert.matches("print%(sp%.latex%(1%+1%)%)", result)
			assert.matches("print%('END'%)", result)
		end)
	end)

	describe("Wolfram", function()
		it("generates null init to flush banner", function()
			local init = wolfram.get_persistent_init()
			assert.equals("Null", init)
		end)

		it("formats input to print TeXForm and delimiter", function()
			local code = "Sin[x]"
			local delimiter = "END"
			local result = wolfram.format_persistent_input(code, delimiter)

			assert.matches("TeXForm%[Quiet%[Sin%[x%]%]%]", result)
			assert.matches('Print%["END"%]', result)
		end)

		it("uses InputForm and UnitSimplify for persistent unit expressions", function()
			local ast = { type = "quantity" }
			local result = wolfram.format_persistent_input('Quantity[10.5, "Meters"]', "END", { ast = ast })

			assert.is_truthy(result:find("FormatType -> InputForm", 1, true))
			assert.is_truthy(result:find("UnitSimplify", 1, true))
		end)

		it("normalizes persistent Wolfram quantities back to siunitx", function()
			local raw = 'Out[1]= Quantity[10.5, "Meters"]'
			local clean = wolfram.sanitize_persistent_output(raw, { ast = { type = "quantity" } })

			assert.equals("\\qty{10.5}{\\meter}", clean)
		end)

		it("sanitizes output by removing prompts", function()
			local raw = "In[1]:= \nOut[1]= 2"
			local clean = wolfram.sanitize_persistent_output(raw)
			assert.equals("2", clean)
		end)
	end)
end)
