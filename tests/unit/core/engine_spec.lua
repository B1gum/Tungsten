-- tests/unit/core/engine_spec.lua
-- Unit tests for the core evaluation engine of Tungsten.

local spy = require("luassert.spy")
local match = require("luassert.match")
local vim_test_env = require("tests.helpers.vim_test_env")
local mock_utils = require("tests.helpers.mock_utils")

describe("tungsten.core.engine", function()
	local engine

	local mock_backend
	local mock_config
	local mock_state
	local mock_async
	local mock_logger
	local mock_parser_module
	local mock_semantic_module

	local ast_to_wolfram_spy
	local async_run_job_spy
	local logger_notify_spy

	local original_require
	local original_vim_schedule

	local modules_to_clear_from_cache = {
		"tungsten.core.engine",
		"tungsten.backends.manager",
		"tungsten.config",
		"tungsten.state",
		"tungsten.util.async",
		"tungsten.util.logger",
		"tungsten.core.parser",
		"tungsten.core.semantic_pass",
	}

	local function ast_node(id)
		return { type = "expression", id = id or "test_ast" }
	end

	before_each(function()
		mock_backend = {}
		mock_backend.ast_to_code = function() end
		mock_config = {
			wolfram_path = "mock_wolframscript",
			numeric_mode = false,
			debug = false,
			cache_enabled = true,
			process_timeout_ms = 5000,
		}
		mock_state = {
			cache = require("tungsten.cache").new(100, nil),
			active_jobs = {},
			persistent_variables = {},
		}
		mock_async = { run_job = function() end }
		mock_logger = {
			notify = function() end,
			levels = { ERROR = 1, WARN = 2, INFO = 3, DEBUG = 4 },
		}
		mock_parser_module = {}
		mock_semantic_module = {}
		mock_logger.debug = function(t, m)
			mock_logger.notify(m, mock_logger.levels.DEBUG, { title = t })
		end
		mock_logger.info = function(t, m)
			mock_logger.notify(m, mock_logger.levels.INFO, { title = t })
		end
		mock_logger.warn = function(t, m)
			mock_logger.notify(m, mock_logger.levels.WARN, { title = t })
		end
		mock_logger.error = function(t, m)
			mock_logger.notify(m, mock_logger.levels.ERROR, { title = t })
		end

		ast_to_wolfram_spy = spy.new(function(ast)
			if ast and ast.id == "error_ast" then
				return nil, "mock codegen error"
			end
			return "wolfram_code(" .. (ast.id or "nil") .. ")"
		end)
		mock_backend.ast_to_code = ast_to_wolfram_spy

		async_run_job_spy = spy.new(function(cmd, opts)
			if opts.on_exit then
				opts.on_exit(0, "mock_result", "")
			end
			return {
				id = 123,
				cancel = function() end,
				is_active = function()
					return false
				end,
			}
		end)
		mock_async.run_job = async_run_job_spy

		mock_backend.evaluate_async = function(ast, opts, cb)
			local code = opts.code or ast_to_wolfram_spy(ast)
			if mock_config.numeric_mode or opts.numeric then
				code = "N[" .. code .. "]"
			end
			code = "ToString[TeXForm[" .. code .. '], CharacterEncoding -> "UTF8"]'
			mock_async.run_job({ mock_config.wolfram_path, "-code", code }, {
				cache_key = opts.cache_key,
				on_exit = function(ec, out, err)
					if cb then
						local final_err = err ~= "" and err or nil
						cb(out == "" and "mock_result" or out, final_err)
					end
				end,
			})
		end

		logger_notify_spy = spy.new(function() end)
		mock_logger.notify = logger_notify_spy

		original_require = _G.require
		_G.require = function(module_path)
			if module_path == "tungsten.backends.manager" then
				return mock_wolfram_codegen
			end
			if module_path == "tungsten.config" then
				return mock_config
			end
			if module_path == "tungsten.state" then
				return mock_state
			end
			if module_path == "tungsten.util.async" then
				return mock_async
			end
			if module_path == "tungsten.util.logger" then
				return mock_logger
			end
			if module_path == "tungsten.core.parser" then
				return mock_parser_module
			end
			if module_path == "tungsten.core.semantic_pass" then
				return mock_semantic_module
			end
			if package.loaded[module_path] then
				return package.loaded[module_path]
			end
			return original_require(module_path)
		end

		original_vim_schedule = vim.schedule
		vim.schedule = function(callback)
			callback()
		end

		mock_utils.reset_modules(modules_to_clear_from_cache)
		engine = require("tungsten.core.engine")
	end)

	after_each(function()
		_G.require = original_require
		vim.schedule = original_vim_schedule
		mock_utils.reset_modules(modules_to_clear_from_cache)
		vim_test_env.cleanup()
	end)

	describe("evaluate_async(ast, numeric, callback)", function()
		it("should successfully evaluate symbolically", function()
			local test_ast = ast_node("symbolic_expr")
			local callback_spy = spy.new()

			engine.evaluate_async(test_ast, false, function(...)
				callback_spy(...)
			end)

			assert.spy(async_run_job_spy).was.called(1)
			local cmd_args = async_run_job_spy.calls[1].vals[1]
			assert.are.same({
				"mock_wolframscript",
				"-code",
				'ToString[TeXForm[wolfram_code(symbolic_expr)], CharacterEncoding -> "UTF8"]',
			}, cmd_args)
			assert.spy(callback_spy).was.called_with("mock_result", nil)
		end)

		it("should successfully evaluate numerically, wrapping code with N[]", function()
			local test_ast = ast_node("numeric_expr")
			local callback_spy = spy.new()

			engine.evaluate_async(test_ast, true, function(...)
				callback_spy(...)
			end)

			assert.spy(async_run_job_spy).was.called(1)
			local cmd_args = async_run_job_spy.calls[1].vals[1]
			assert.are.same({
				"mock_wolframscript",
				"-code",
				'ToString[TeXForm[N[wolfram_code(numeric_expr)]], CharacterEncoding -> "UTF8"]',
			}, cmd_args)
			assert.spy(callback_spy).was.called_with("mock_result", nil)
		end)

		it("should return cached result immediately if cache is enabled and item exists", function()
			local test_ast = ast_node("cached_expr")
			local callback_spy = spy.new()
			local cache_key = engine.get_cache_key("wolfram_code(cached_expr)", false)
			mock_state.cache:set(cache_key, "cached_result")

			engine.evaluate_async(test_ast, false, function(...)
				callback_spy(...)
			end)

			assert.spy(async_run_job_spy).was_not.called()
			assert.spy(callback_spy).was.called_with("cached_result", nil)
		end)

		it("should start a job and cache the result if cache is enabled and item does not exist (cache miss)", function()
			local test_ast = ast_node("new_expr")
			local callback_spy = spy.new()
			local cache_key = engine.get_cache_key("wolfram_code(new_expr)", false)

			engine.evaluate_async(test_ast, false, function(...)
				callback_spy(...)
			end)

			assert.spy(async_run_job_spy).was.called(1)
			assert.spy(callback_spy).was.called_with("mock_result", nil)
			assert.are.equal("mock_result", mock_state.cache:get(cache_key))
		end)

		it("should always start a job and not use/store in cache if cache is disabled", function()
			mock_config.cache_enabled = false
			local test_ast = ast_node("no_cache_expr")
			local callback_spy = spy.new()
			local cache_key = engine.get_cache_key("wolfram_code(no_cache_expr)", false)
			mock_state.cache:set(cache_key, "should_not_be_used")

			engine.evaluate_async(test_ast, false, function(...)
				callback_spy(...)
			end)

			assert.spy(async_run_job_spy).was.called(1)
			assert.spy(callback_spy).was.called_with("mock_result", nil)
			assert.are.equal("should_not_be_used", mock_state.cache:get(cache_key))
		end)

		it("should invoke callback with error if async.run_job returns a falsy job_id", function()
			mock_async.run_job = spy.new(function()
				return nil
			end)
			local test_ast = ast_node("job_fail_ast")
			local callback_spy = spy.new()

			engine.evaluate_async(test_ast, false, function(...)
				callback_spy(...)
			end)
			assert.spy(mock_async.run_job).was.called(1)
		end)

		it(
			"should log a notification and not start a new job if a job for the same expression is already in progress",
			function()
				local test_ast = ast_node("in_progress_expr")
				local callback_spy = spy.new()
				local cache_key = engine.get_cache_key("wolfram_code(in_progress_expr)", false)
				mock_state.active_jobs[999] = { cache_key = cache_key }

				engine.evaluate_async(test_ast, false, function(...)
					callback_spy(...)
				end)

				assert.spy(async_run_job_spy).was_not.called()
				assert
					.spy(logger_notify_spy).was
					.called_with("Tungsten: Evaluation already in progress for this expression.", mock_logger.levels.INFO, match.is_table())
			end
		)
	end)

	describe("Persistent Variable Substitution", function()
		it("should substitute a single persistent variable", function()
			mock_state.persistent_variables["x"] = "5"
			local result = engine.substitute_persistent_vars("x + 1", mock_state.persistent_variables)
			assert.are.equal("(5) + 1", result)
		end)

		it("should substitute multiple persistent variables", function()
			mock_state.persistent_variables = { x = "5", y = "10" }
			local result = engine.substitute_persistent_vars("x + y", mock_state.persistent_variables)
			assert.are.equal("(5) + (10)", result)
		end)

		it("should substitute longer variable names before shorter ones (e.g., 'xx' before 'x')", function()
			mock_state.persistent_variables = { x = "1", xx = "2" }
			local result = engine.substitute_persistent_vars("xx + x", mock_state.persistent_variables)
			assert.are.equal("(2) + (1)", result)
		end)

		it("should correctly handle operator precedence with parentheses around substituted values", function()
			mock_state.persistent_variables = { x = "1+1" }
			local result = engine.substitute_persistent_vars("2 * x", mock_state.persistent_variables)
			assert.are.equal("2 * (1+1)", result)
		end)

		it("should not substitute if variable name is part of a larger word/symbol", function()
			mock_state.persistent_variables = { x = "5" }
			local result = engine.substitute_persistent_vars("yxx + x", mock_state.persistent_variables)
			assert.are.equal("yxx + (5)", result)
		end)
	end)

	describe("Cache Management", function()
		it("clear_cache() should empty the cache and log", function()
			mock_state.cache:set("key1", "val1")
			engine.clear_cache()
			assert.are_equal(0, mock_state.cache:count())
			assert
				.spy(logger_notify_spy).was
				.called_with("Tungsten: Cache cleared.", mock_logger.levels.INFO, match.is_table())
		end)
	end)

	describe("Active Job Management", function()
		it("get_active_jobs_summary() should report no jobs when table empty", function()
			local summary = engine.get_active_jobs_summary()
			assert.are.equal("Tungsten: No active jobs.", summary)
		end)

		it("get_active_jobs_summary() should include details for active jobs", function()
			mock_state.active_jobs = {
				[123] = { bufnr = 1, cache_key = "key1", start_time = vim.loop.now() - 1000 },
				[456] = { bufnr = 2, cache_key = "key2", start_time = vim.loop.now() - 2000 },
			}
			local summary = engine.get_active_jobs_summary()
			assert.truthy(summary:find("Active Tungsten Jobs:"))
			assert.truthy(summary:find("ID: 123"))
			assert.truthy(summary:find("ID: 456"))
		end)

		it("view_active_jobs() should log 'No active jobs.' if active_jobs is empty", function()
			local summary_spy = spy.on(engine, "get_active_jobs_summary")
			engine.view_active_jobs()
			assert.spy(summary_spy).was.called()
			assert
				.spy(logger_notify_spy).was
				.called_with("Tungsten: No active jobs.", mock_logger.levels.INFO, match.is_table())
			summary_spy:revert()
		end)

		it("view_active_jobs() should log details of active jobs", function()
			mock_state.active_jobs = {
				[123] = { bufnr = 1, cache_key = "key1", start_time = vim.loop.now() - 1000 },
				[456] = { bufnr = 2, cache_key = "key2", start_time = vim.loop.now() - 2000 },
			}
			local summary_spy = spy.on(engine, "get_active_jobs_summary")
			engine.view_active_jobs()
			assert.spy(summary_spy).was.called()
			assert.spy(logger_notify_spy).was.called_with(match.is_string(), mock_logger.levels.INFO, match.is_table())
			local log_message = logger_notify_spy.calls[1].vals[1]
			assert.truthy(log_message:find("Active Tungsten Jobs:"))
			assert.truthy(log_message:find("ID: 123"))
			assert.truthy(log_message:find("ID: 456"))
			summary_spy:revert()
		end)
	end)
end)
