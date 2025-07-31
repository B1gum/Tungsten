local spy = require("luassert.spy")
local mock_utils = require("tests.helpers.mock_utils")

describe("engine missing binary feedback", function()
	local engine
	local mock_backend
	local mock_config
	local mock_state
	local mock_async
	local mock_logger
	local async_run_job_spy
	local callback_spy
	local mock_exit_code

	local original_require
	local original_vim_schedule

	local modules_to_clear_from_cache = {
		"tungsten.core.engine",
		"tungsten.backends.manager",
		"tungsten.config",
		"tungsten.state",
		"tungsten.util.async",
		"tungsten.util.logger",
	}

	local function ast()
		return { type = "expression", id = "test_ast" }
	end

	before_each(function()
		mock_backend = {}
		mock_backend.ast_to_code = function()
			return "wolfram_code"
		end
		mock_config = {
			wolfram_path = "mock_wolframscript",
			numeric_mode = false,
			debug = false,
			cache_enabled = false,
			process_timeout_ms = 5000,
		}
		mock_state = { cache = {}, active_jobs = {}, persistent_variables = {} }
		mock_logger = { notify = function() end, levels = { ERROR = 1, WARN = 2, INFO = 3, DEBUG = 4 } }
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

		async_run_job_spy = spy.new(function(_, opts)
			if opts.on_exit then
				opts.on_exit(mock_exit_code or -1, "", "")
			end
			return {
				id = 1,
				cancel = function() end,
				is_active = function()
					return false
				end,
			}
		end)
		mock_async = { run_job = async_run_job_spy }
		mock_backend.evaluate_async = function(_, opts, cb)
			mock_async.run_job({ mock_config.wolfram_path, "-code", opts.code or "" }, {
				cache_key = opts.cache_key,
				on_exit = function(code, out, err)
					if cb then
						if code == 0 then
							cb(out, nil)
						else
							local err_msg
							if code == -1 or code == 127 then
								err_msg = "WolframScript not found. Check wolfram_path."
							else
								err_msg = string.format("WolframScript exited with code %d", code)
							end
							cb(nil, err_msg)
						end
					end
				end,
			})
		end

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
			if package.loaded[module_path] then
				return package.loaded[module_path]
			end
			return original_require(module_path)
		end

		original_vim_schedule = vim.schedule
		vim.schedule = function(fn)
			fn()
		end

		mock_utils.reset_modules(modules_to_clear_from_cache)
		engine = require("tungsten.core.engine")
	end)

	after_each(function()
		_G.require = original_require
		vim.schedule = original_vim_schedule
		mock_utils.reset_modules(modules_to_clear_from_cache)
	end)

	local function run_with_code(code)
		mock_exit_code = code
		callback_spy = spy.new()
		engine.evaluate_async(ast(), false, function(...)
			callback_spy(...)
		end)
	end

	it("returns helpful message when exit code is -1", function()
		run_with_code(-1)
		assert.spy(callback_spy).was.called_with(nil, "WolframScript not found. Check wolfram_path.")
	end)

	it("returns helpful message when exit code is 127", function()
		run_with_code(127)
		assert.spy(callback_spy).was.called_with(nil, "WolframScript not found. Check wolfram_path.")
	end)
end)
