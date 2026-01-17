local lfs = require("lfs")
local spy = require("luassert.spy")
local match = require("luassert.match")

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

		it("rejects non-table metadata", function()
			local ok, err = dm.validate_metadata("nope")
			assert.is_false(ok)
			assert.equals("domain module must return a table", err)
		end)

		it("rejects invalid grammar table", function()
			local ok, err = dm.validate_metadata({ name = "demo" })
			assert.is_false(ok)
			assert.equals("missing grammar table", err)
		end)

		it("rejects invalid contributions list", function()
			local ok, err = dm.validate_metadata({ name = "demo", grammar = {} })
			assert.is_false(ok)
			assert.equals("grammar.contributions must be table", err)
		end)

		it("rejects invalid commands and handlers", function()
			local ok, err = dm.validate_metadata({
				name = "demo",
				grammar = { contributions = {} },
				commands = true,
			})
			assert.is_false(ok)
			assert.equals("commands must be table or nil", err)

			ok, err = dm.validate_metadata({
				name = "demo",
				grammar = { contributions = {} },
				handlers = {},
			})
			assert.is_false(ok)
			assert.equals("handlers must be function or nil", err)
		end)
	end)

	describe("when registering domains", function()
		local registry_mock
		local logger_mock
		local config
		local orig_require

		before_each(function()
			registry_mock = {
				register_domain_metadata = spy.new(function() end),
				register_grammar_contribution = spy.new(function() end),
				register_command = spy.new(function() end),
			}
			logger_mock = { notify = spy.new(function() end), levels = { ERROR = 1 } }
			config = { domains = {} }
			package.loaded["tungsten.core.registry"] = registry_mock
			package.loaded["tungsten.util.logger"] = logger_mock
			package.loaded["tungsten.config"] = config
			package.loaded["tungsten.core.domain_manager"] = nil
			dm = require("tungsten.core.domain_manager")
			orig_require = _G.require
		end)

		after_each(function()
			_G.require = orig_require
			package.loaded["tungsten.core.registry"] = nil
			package.loaded["tungsten.util.logger"] = nil
			package.loaded["tungsten.config"] = nil
			package.loaded["tungsten.core.domain_manager"] = nil
			package.loaded["tungsten.domains.bad"] = nil
			package.loaded["tungsten.domains.good"] = nil
			package.loaded["tungsten.domains.func"] = nil
			_G.commands_called = nil
		end)

		it("logs an error when the module cannot be loaded", function()
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
				if mod == "tungsten.domains.missing" then
					error("missing module")
				end
				return orig_require(mod)
			end

			local mod, err = dm.register_domain("missing")
			assert.is_nil(mod)
			assert.is_not_nil(err)
			assert.spy(logger_mock.notify).was.called_with(match.is_string(), logger_mock.levels.ERROR, match.table())
		end)

		it("logs an error when metadata is invalid", function()
			package.loaded["tungsten.domains.bad"] = { grammar = { contributions = {} } }
			local mod, err = dm.register_domain("bad")
			assert.is_nil(mod)
			assert.is_not_nil(err)
			assert.spy(logger_mock.notify).was.called_with(match.is_string(), logger_mock.levels.ERROR, match.table())
		end)

		it("invokes command registration functions", function()
			dm.validate_metadata = function()
				return true
			end
			package.loaded["tungsten.domains.func"] = {
				name = "func",
				grammar = { contributions = {} },
				commands = function()
					_G.commands_called = true
				end,
			}

			local mod = dm.register_domain("func")
			assert.is_not_nil(mod)
			assert.is_true(_G.commands_called)
			assert.spy(registry_mock.register_command).was_not.called()
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

			registry_mock = {
				register_domain_metadata = spy.new(function() end),
				register_grammar_contribution = spy.new(function() end),
				register_command = spy.new(function() end),
			}
			package.loaded["tungsten.core.registry"] = registry_mock
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

	describe("dependency ordering", function()
		local registry_mock
		local logger_mock
		local config

		before_each(function()
			registry_mock = {
				register_domain_metadata = spy.new(function() end),
				register_grammar_contribution = spy.new(function() end),
			}
			logger_mock = { notify = spy.new(function() end), levels = { ERROR = 1 } }
			config = { domains = { "alpha" } }
			package.loaded["tungsten.core.registry"] = registry_mock
			package.loaded["tungsten.util.logger"] = logger_mock
			package.loaded["tungsten.config"] = config
			package.loaded["tungsten.domains.alpha"] = {
				name = "alpha",
				grammar = { contributions = {} },
				dependencies = { "beta" },
			}
			package.loaded["tungsten.domains.beta"] = {
				name = "beta",
				grammar = { contributions = {} },
			}
			package.loaded["tungsten.core.domain_manager"] = nil
			dm = require("tungsten.core.domain_manager")
		end)

		after_each(function()
			package.loaded["tungsten.core.registry"] = nil
			package.loaded["tungsten.util.logger"] = nil
			package.loaded["tungsten.config"] = nil
			package.loaded["tungsten.domains.alpha"] = nil
			package.loaded["tungsten.domains.beta"] = nil
			package.loaded["tungsten.core.domain_manager"] = nil
		end)

		it("registers dependencies before dependents", function()
			dm.setup()
			assert.spy(registry_mock.register_domain_metadata).was.called_with("beta", match._)
			assert.spy(registry_mock.register_domain_metadata).was.called_with("alpha", match._)
			assert.equals("beta", registry_mock.register_domain_metadata.calls[1].vals[1])
			assert.equals("alpha", registry_mock.register_domain_metadata.calls[2].vals[1])
		end)
	end)

	describe("cyclic dependencies", function()
		local registry_mock
		local logger_mock
		local config

		before_each(function()
			registry_mock = {
				register_domain_metadata = spy.new(function() end),
				register_grammar_contribution = spy.new(function() end),
			}
			logger_mock = { notify = spy.new(function() end), levels = { ERROR = 1 } }
			config = { domains = { "alpha" } }
			package.loaded["tungsten.core.registry"] = registry_mock
			package.loaded["tungsten.util.logger"] = logger_mock
			package.loaded["tungsten.config"] = config
			package.loaded["tungsten.domains.alpha"] = {
				name = "alpha",
				grammar = { contributions = {} },
				dependencies = { "beta" },
			}
			package.loaded["tungsten.domains.beta"] = {
				name = "beta",
				grammar = { contributions = {} },
				dependencies = { "alpha" },
			}
			package.loaded["tungsten.core.domain_manager"] = nil
			dm = require("tungsten.core.domain_manager")
		end)

		after_each(function()
			package.loaded["tungsten.core.registry"] = nil
			package.loaded["tungsten.util.logger"] = nil
			package.loaded["tungsten.config"] = nil
			package.loaded["tungsten.domains.alpha"] = nil
			package.loaded["tungsten.domains.beta"] = nil
			package.loaded["tungsten.core.domain_manager"] = nil
		end)

		it("logs cyclic dependency warnings", function()
			dm.setup()
			assert.spy(logger_mock.notify).was.called_with(match.is_string(), logger_mock.levels.ERROR, match.table())
		end)
	end)

	describe("user-defined domains path", function()
		local registry_mock
		local logger_mock
		local config

		before_each(function()
			config = require("tungsten.config")
			config.user_domains_path = "/user/domains"
			config.domains = { "plugdom", "userdom" }

			registry_mock = {
				register_domain_metadata = spy.new(function() end),
				register_grammar_contribution = spy.new(function() end),
			}
			package.loaded["tungsten.core.registry"] = registry_mock
			logger_mock = { notify = spy.new(function() end), levels = { ERROR = 1 } }
			package.loaded["tungsten.util.logger"] = logger_mock

			package.loaded["tungsten.core.domain_manager"] = nil
			dm = require("tungsten.core.domain_manager")
		end)

		after_each(function()
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
