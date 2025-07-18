local lfs = require("lfs")
local mock_utils = require("tests.helpers.mock_utils")
local spy = require("luassert.spy")
local match = require("luassert.match")

describe("DomainManager.reload", function()
	local dm
	local tmp_dir
	local registry_mock
	local logger_mock
	local orig_domain

	before_each(function()
		tmp_dir = vim.loop.fs_mkdtemp("tungsten_dm_reloadXXXXXX")
		lfs.mkdir(tmp_dir .. "/tungsten")
		lfs.mkdir(tmp_dir .. "/tungsten/domains")
		lfs.mkdir(tmp_dir .. "/tungsten/domains/dom1")
		local f = io.open(tmp_dir .. "/tungsten/domains/dom1/init.lua", "w")
		f:write([[return {
      name='dom1',
      grammar={ contributions={}, extensions={} }
    }]])
		f:close()

		registry_mock = mock_utils.create_empty_mock_module("tungsten.core.registry", {
			"register_domain_metadata",
			"register_grammar_contribution",
			"reset",
		})
		logger_mock = {
			notify = spy.new(function() end),
			levels = { ERROR = 1 },
			info = function() end,
		}
		package.loaded["tungsten.util.logger"] = logger_mock
		package.path = tmp_dir .. "/?.lua;" .. tmp_dir .. "/?/init.lua;" .. package.path
		local cfg = require("tungsten.config")
		orig_domains = cfg.domains
		cfg.domains = nil
		package.loaded["tungsten.core.domain_manager"] = nil
		dm = require("tungsten.core.domain_manager")
	end)

	after_each(function()
		package.loaded["tungsten.core.registry"] = nil
		package.loaded["tungsten.util.logger"] = nil
		package.loaded["tungsten.core.domain_manager"] = nil
		require("tungsten.config").domains = orig_domains
		os.execute("rm -rf " .. tmp_dir)
	end)

	it("loads newly added domains on reload", function()
		dm.setup({ domains_dir = tmp_dir .. "/tungsten/domains" })
		assert.spy(registry_mock.register_domain_metadata).was.called_with("dom1", match._)

		lfs.mkdir(tmp_dir .. "/tungsten/domains/dom2")
		local f = io.open(tmp_dir .. "/tungsten/domains/dom2/init.lua", "w")
		f:write([[return {
      name='dom2',
      grammar={ contributions={}, extensions={} }
    }]])
		f:close()

		dm.reload({ domains_dir = tmp_dir .. "/tungsten/domains" })

		assert.spy(registry_mock.reset).was.called(1)
		assert.spy(registry_mock.register_domain_metadata).was.called_with("dom2", match._)
	end)
end)
