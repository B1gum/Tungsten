-- tests/unit/util/async_missing_plenary_spec.lua
local mock_utils = require("tests.helpers.mock_utils")

describe("async.run_job missing plenary", function()
	local original_require

	before_each(function()
		mock_utils.reset_modules({ "tungsten.util.async" })
		original_require = _G.require
		_G.require = function(mod)
			if mod == "plenary.job" then
				error("module 'plenary.job' not found")
			end
			return original_require(mod)
		end
	end)

	after_each(function()
		_G.require = original_require
		mock_utils.reset_modules({ "tungsten.util.async" })
	end)

	it("throws helpful error when plenary.job is missing", function()
		local async = require("tungsten.util.async")
		assert.has_error(function()
			async.run_job({ "echo", "hi" })
		end, "async.run_job: plenary.nvim is required. Install https://github.com/nvim-lua/plenary.nvim.")
	end)
end)
