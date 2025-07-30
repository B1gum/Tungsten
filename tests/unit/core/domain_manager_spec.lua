local lfs = require("lfs")
local mock_utils = require("tests.helpers.mock_utils")
local spy = require("luassert.spy")

describe("DomainManager", function()
	local dm
	before_each(function()
		package.loaded["tungsten.core.domain_manager"] = nil
		dm = require("tungsten.core.domain_manager")
	end)

	describe("when validating metadata", function()
		it("accepts valid metadata", function()
			local ok, err = dm.validate_metadata({
				name = "demo",
				grammar = { contributions = {}, extensions = {} },
				commands = {},
				handlers = function() end,
			})
			assert.is_true(ok)
			assert.is_nil(err)
		end)

		it("rejects missing name", function()
			local ok, err = dm.validate_metadata({
				grammar = { contributions = {} },
			})
			assert.is_false(ok)
			assert.is_not_nil(err)
		end)
	end)

	describe("integration", function()
		local tmp_dir
		local registry_mock
		local logger_mock
		local orig_domains
		before_each(function()
			tmp_dir = vim.loop.fs_mkdtemp("tungsten_dm_integXXXXXX")
			lfs.mkdir(tmp_dir .. "/tungsten")
			lfs.mkdir(tmp_dir .. "/tungsten/domains")
			lfs.mkdir(tmp_dir .. "/tungsten/domains/dom1")
			local f = io.open(tmp_dir .. "/tungsten/domains/dom1/init.lua", "w")
			f:write([[return {
        name='dom1', priority=10,
        grammar={ contributions={ {name='Num', pattern='p1', category='AtomBaseItem'} }, extensions={} },
        commands={{ name='Dom1Cmd', func=function() _G.dom1_commands_called = true end, opts={} }},
        handlers=function() _G.dom1_handlers_called = true end,
      }]])
			f:close()

			lfs.mkdir(tmp_dir .. "/tungsten/domains/dom2")
			f = io.open(tmp_dir .. "/tungsten/domains/dom2/init.lua", "w")
			f:write([[return {
        name='dom2', priority=5,
        grammar={ contributions={ {name='Var', pattern='p2', category='AtomBaseItem'} }, extensions={} },
      }]])
			f:close()

			registry_mock = mock_utils.create_empty_mock_module("tungsten.core.registry", {
				"register_domain_metadata",
				"register_grammar_contribution",
				"register_command",
			})
			logger_mock = { notify = spy.new(function() end), levels = { ERROR = 1 } }
			package.loaded["tungsten.util.logger"] = logger_mock
			local cfg = require("tungsten.config")
			orig_domains = cfg.domains
			cfg.domains = { "dom1", "dom2" }
			package.path = tmp_dir .. "/?.lua;" .. tmp_dir .. "/?/init.lua;" .. package.path
			package.loaded["tungsten.core.domain_manager"] = nil
			dm = require("tungsten.core.domain_manager")
		end)

		after_each(function()
			package.loaded["tungsten.core.registry"] = nil
			package.loaded["tungsten.util.logger"] = nil
			package.loaded["tungsten.core.domain_manager"] = nil
			os.execute("rm -rf " .. tmp_dir)
			require("tungsten.config").domains = orig_domains
			_G.dom1_commands_called = nil
			_G.dom1_handlers_called = nil
		end)

		it("registers grammar and loads hooks", function()
			dm.setup()
			assert.spy(registry_mock.register_domain_metadata).was.called_with("dom1", match._)
			assert.spy(registry_mock.register_domain_metadata).was.called_with("dom2", match._)
			assert.spy(registry_mock.register_grammar_contribution).was.called_with("dom1", 10, "Num", "p1", "AtomBaseItem")
			assert.spy(registry_mock.register_grammar_contribution).was.called_with("dom2", 5, "Var", "p2", "AtomBaseItem")
			assert.spy(registry_mock.register_command).was.called_with(match.table({ name = "Dom1Cmd" }))
			assert.is_nil(_G.dom1_commands_called)
			assert.is_nil(_G.dom1_handlers_called)
		end)
	end)

	describe("user-defined domains path", function()
		local registry_mock
		local logger_mock
		local config

		before_each(function()
			config = require("tungsten.config")
			config.user_domains_path = "/user/domains"
			orig_domains = config.domains
			config.domains = { "plugdom", "userdom" }

			registry_mock = mock_utils.create_empty_mock_module("tungsten.core.registry", {
				"register_domain_metadata",
				"register_grammar_contribution",
			})
			logger_mock = { notify = spy.new(function() end), levels = { ERROR = 1 } }
			package.loaded["tungsten.util.logger"] = logger_mock

			package.loaded["tungsten.core.domain_manager"] = nil
			dm = require("tungsten.core.domain_manager")
		end)

		after_each(function()
			config.domains = orig_domains
			package.loaded["tungsten.core.registry"] = nil
			package.loaded["tungsten.util.logger"] = nil
			package.loaded["tungsten.core.domain_manager"] = nil
		end)

		it("registers domains from plugin and user paths", function()
			local req_spy = spy.new(function(mod)
				return { name = mod:match("%.([^%.]+)$"), grammar = { contributions = {} } }
			end)
			local orig_require = _G.require
			_G.require = function(mod)
				if mod == "tungsten.core.registry" then
					return registry_mock
				end
				if mod == "tungsten.util.logger" then
					return logger_mock
				end
				if mod == "tungsten.config" then
					return config
				end
				if mod == "tungsten.domains.plugdom" or mod == "tungsten.domains.userdom" then
					return req_spy(mod)
				end
				if package.loaded[mod] then
					return package.loaded[mod]
				end
				return orig_require(mod)
			end

			dm.setup()
			_G.require = orig_require

			assert.spy(registry_mock.register_domain_metadata).was.called_with("plugdom", match._)
			assert.spy(registry_mock.register_domain_metadata).was.called_with("userdom", match._)
		end)
	end)
end)
