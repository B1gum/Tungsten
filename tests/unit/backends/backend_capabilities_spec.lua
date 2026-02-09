-- Unit tests for backend plotting capabilities and error handling.
local backends = require("tungsten.domains.plotting.backends")

describe("backend capabilities", function()
	it("flags python explicit x functions as unsupported", function()
		assert.is_false(backends.is_supported("python", "explicit", 2, { dependent_vars = { "x" } }))
	end)
end)
