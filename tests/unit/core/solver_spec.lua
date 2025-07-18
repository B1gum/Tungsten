-- tests/unit/core/solver_spec.lua
-- Unit tests for the Tungsten equation solver.

local spy = require("luassert.spy")
local match = require("luassert.match")
local mock_utils = require("tests.helpers.mock_utils")

local solver
local solution_helper

local mock_evaluator_module
local mock_config_module
local mock_logger_module
local mock_state_module
local mock_async_module

local modules_to_clear_from_cache = {
	"tungsten.core.solver",
	"tungsten.core.engine",
	"tungsten.util.async",
	"tungsten.config",
	"tungsten.state",
	"tungsten.util.logger",
}

describe("tungsten.core.solver", function()
	local original_require

	before_each(function()
		mock_utils.reset_modules(modules_to_clear_from_cache)

		mock_evaluator_module = {
			substitute_persistent_vars = spy.new(function(wolfram_str)
				return wolfram_str
			end),
		}
		mock_config_module = {
			wolfram_path = "mock_wolframscript_path",
			debug = false,
			process_timeout_ms = 5000,
		}
		mock_logger_module = {
			levels = { ERROR = 1, WARN = 2, INFO = 3, DEBUG = 4 },
			notify = spy.new(function() end),
		}
		mock_logger_module.debug = function(t, m)
			mock_logger_module.notify(m, mock_logger_module.levels.DEBUG, { title = t })
		end
		mock_logger_module.info = function(t, m)
			mock_logger_module.notify(m, mock_logger_module.levels.INFO, { title = t })
		end
		mock_logger_module.warn = function(t, m)
			mock_logger_module.notify(m, mock_logger_module.levels.WARN, { title = t })
		end
		mock_logger_module.error = function(t, m)
			mock_logger_module.notify(m, mock_logger_module.levels.ERROR, { title = t })
		end
		mock_state_module = {
			persistent_variables = {},
			active_jobs = {},
		}
		mock_async_module = {
			run_job = spy.new(function(cmd, opts)
				if opts.on_exit then
					opts.on_exit(0, "{{x -> 1}}", "")
				end
				return {
					id = 1,
					cancel = function() end,
					is_active = function()
						return false
					end,
				}
			end),
		}

		original_require = _G.require
		_G.require = function(module_path)
			if module_path == "tungsten.core.engine" then
				return mock_evaluator_module
			end
			if module_path == "tungsten.config" then
				return mock_config_module
			end
			if module_path == "tungsten.util.logger" then
				return mock_logger_module
			end
			if module_path == "tungsten.state" then
				return mock_state_module
			end
			if module_path == "tungsten.util.async" then
				return mock_async_module
			end
			if package.loaded[module_path] then
				return package.loaded[module_path]
			end
			return original_require(module_path)
		end

		solver = require("tungsten.core.solver")
		solution_helper = require("tungsten.backends.wolfram.wolfram_solution")
	end)

	after_each(function()
		_G.require = original_require
		mock_utils.reset_modules(modules_to_clear_from_cache)
	end)

	describe("parse_wolfram_solution", function()
		it("handles single variable", function()
			local res = solution_helper.parse_wolfram_solution("{{x -> 2}}", { "x" }, false)
			assert.is_true(res.ok)
			assert.are.equal("x = 2", res.formatted)
		end)

		it("handles system of equations", function()
			local res = solution_helper.parse_wolfram_solution("{{x -> 1, y -> -3}}", { "x", "y" }, true)
			assert.is_true(res.ok)
			assert.are.equal("x = 1, y = -3", res.formatted)
		end)

		it("returns no solution when output empty", function()
			local res = solution_helper.parse_wolfram_solution("", { "x" }, false)
			assert.is_false(res.ok)
			assert.are.equal("No solution", res.reason)
		end)

		it("handles timeout-like nil output", function()
			local res = solution_helper.parse_wolfram_solution(nil, { "x" }, false)
			assert.is_false(res.ok)
		end)
	end)

	describe("M.solve_equation_async(eq_wolfram_strs, var_wolfram_strs, is_system, callback)", function()
		local callback_spy

		before_each(function()
			callback_spy = spy.new(function() end)
		end)

		it("should correctly form Wolfram command for a single equation", function()
			solver.solve_equation_async({ "x+1==2" }, { "x" }, false, callback_spy)
			assert.spy(mock_async_module.run_job).was.called(1)
			local job_args = mock_async_module.run_job.calls[1].vals[1]
			assert.are.same(
				{ "mock_wolframscript_path", "-code", 'ToString[TeXForm[Solve[{x+1==2}, {x}]], CharacterEncoding -> "UTF8"]' },
				job_args
			)
		end)

		it("should correctly form Wolfram command for a system of equations", function()
			solver.solve_equation_async({ "x+y==3", "x-y==1" }, { "x", "y" }, true, callback_spy)
			assert.spy(mock_async_module.run_job).was.called(1)
			local job_args = mock_async_module.run_job.calls[1].vals[1]
			assert.are.same(
				{
					"mock_wolframscript_path",
					"-code",
					'ToString[TeXForm[Solve[{x+y==3, x-y==1}, {x, y}]], CharacterEncoding -> "UTF8"]',
				},
				job_args
			)
		end)

		it("should log Wolfram command if debug is true", function()
			mock_config_module.debug = true
			solver = require("tungsten.core.solver")
			solver.solve_equation_async({ "dbg==1" }, { "dbg" }, false, callback_spy)
			assert.spy(mock_logger_module.notify).was.called_with(
				"TungstenSolve: Wolfram command: Solve[{dbg==1}, {dbg}]",
				mock_logger_module.levels.DEBUG,
				{ title = "Tungsten Debug" }
			)
		end)

		it("should handle successful job execution and parse single solution (e.g. {{x -> 1}})", function()
			mock_async_module.run_job = spy.new(function(cmd, opts)
				if opts.on_exit then
					opts.on_exit(0, "{{x -> 1}}", "")
				end
				return {
					id = 2,
					cancel = function() end,
					is_active = function()
						return false
					end,
				}
			end)
			solver.solve_equation_async({ "x==1" }, { "x" }, false, callback_spy)
			assert.spy(callback_spy).was.called_with("x = 1", nil)
		end)

		it("should handle successful job execution and parse system solution (e.g. {{x -> 1, y -> 2}})", function()
			mock_async_module.run_job = spy.new(function(cmd, opts)
				if opts.on_exit then
					opts.on_exit(0, "{{x -> 1, y -> 2}}", "")
				end
				return {
					id = 3,
					cancel = function() end,
					is_active = function()
						return false
					end,
				}
			end)
			solver.solve_equation_async({ "x==1", "y==2" }, { "x", "y" }, true, callback_spy)
			assert.spy(callback_spy).was.called_with("x = 1, y = 2", nil)
		end)

		it("should callback with error if jobstart returns 0 (invalid args)", function()
			mock_async_module.run_job = spy.new(function(cmd, opts)
				if opts.on_exit then
					opts.on_exit(127, "", "Jobstart failed: Invalid arguments")
				end
				return {
					id = 4,
					cancel = function() end,
					is_active = function()
						return false
					end,
				}
			end)
			solver.solve_equation_async({ "x==1" }, { "x" }, false, callback_spy)
			assert.spy(callback_spy).was.called_with(nil, match.is_string())
		end)

		it("should callback with error if jobstart returns -1 (cmd not found)", function()
			mock_async_module.run_job = spy.new(function(cmd, opts)
				if opts.on_exit then
					opts.on_exit(-1, "", "Command not found")
				end
				return {
					id = 5,
					cancel = function() end,
					is_active = function()
						return false
					end,
				}
			end)
			solver.solve_equation_async({ "x==1" }, { "x" }, false, callback_spy)
			assert.spy(callback_spy).was.called_with(nil, match.is_string())
		end)

		it("formats Wolfram errors from stderr when job fails", function()
			mock_async_module.run_job = spy.new(function(cmd, opts)
				if opts.on_exit then
					opts.on_exit(1, "", "Solve::nsmet: no solution")
				end
				return {
					id = 7,
					cancel = function() end,
					is_active = function()
						return false
					end,
				}
			end)
			solver.solve_equation_async({ "bad" }, { "x" }, false, callback_spy)
			assert.spy(callback_spy).was.called_with(nil, "Solve::nsmet: no solution")
		end)

		it("formats Wolfram Message errors when exit code is zero", function()
			mock_async_module.run_job = spy.new(function(cmd, opts)
				if opts.on_exit then
					opts.on_exit(0, "", "Solve::nsmet: no solution")
				end
				return {
					id = 8,
					cancel = function() end,
					is_active = function()
						return false
					end,
				}
			end)
			solver.solve_equation_async({ "bad" }, { "x" }, false, callback_spy)
			assert.spy(callback_spy).was.called_with(nil, "Solve::nsmet: no solution")
		end)

		it("should use default timeout if config.process_timeout_ms is nil", function()
			mock_config_module.process_timeout_ms = nil

			package.loaded["tungsten.util.async"] = nil
			local reloaded_async = require("tungsten.util.async")

			reloaded_async.run_job = spy.new(function(cmd, opts)
				if opts.on_exit then
					opts.on_exit(0, "{{x -> 1}}", "")
				end
				return {
					id = 6,
					cancel = function() end,
					is_active = function()
						return false
					end,
				}
			end)

			local reloaded_solver = require("tungsten.core.solver")

			reloaded_solver.solve_equation_async({ "def_timeout==1" }, { "def_timeout" }, false, callback_spy)

			assert.is_nil(mock_config_module.process_timeout_ms)
			assert.spy(callback_spy).was.called()
		end)
	end)
end)
