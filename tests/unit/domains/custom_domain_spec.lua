local mock_utils = require("tests.helpers.mock_utils")
local match = require("luassert.match")

describe("tungsten.register_domain", function()
	local tmp_dir
	local tungsten
	local registry_mock
	local uv = vim.uv or vim.loop

	before_each(function()
		tmp_dir = uv.fs_mkdtemp("tungsten_custom_domXXXXXX")

		vim.fn.mkdir(tmp_dir .. "/tungsten/domains/custom", "p")

		local f = io.open(tmp_dir .. "/tungsten/domains/custom/init.lua", "w")
		f:write([[return {
      name='custom',
      grammar={ contributions={}, extensions={} }
    }]])
		f:close()

		registry_mock = mock_utils.create_empty_mock_module("tungsten.core.registry", {
			"register_domain_metadata",
			"register_grammar_contribution",
			"register_command",
		})
		package.path = tmp_dir .. "/?.lua;" .. tmp_dir .. "/?/init.lua;" .. package.path

		package.loaded["tungsten"] = nil
		package.loaded["tungsten.core.domain_manager"] = nil
		tungsten = require("tungsten")
	end)

	after_each(function()
		package.loaded["tungsten"] = nil
		package.loaded["tungsten.core.domain_manager"] = nil
		package.loaded["tungsten.core.registry"] = nil

		vim.fn.delete(tmp_dir, "rf")
	end)

	it("loads and registers the domain", function()
		local mod = tungsten.register_domain("custom")
		assert.is_table(mod)
		assert.spy(registry_mock.register_domain_metadata).was.called_with("custom", match._)
	end)
end)
