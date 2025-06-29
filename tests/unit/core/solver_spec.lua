-- tests/unit/core/solver_spec.lua
-- Unit tests for the Tungsten equation solver.
---------------------------------------------------------------------

local vim_test_env = require 'tests.helpers.vim_test_env'

local spy = require 'luassert.spy'
local match = require 'luassert.match'

local solver

local mock_evaluator_module
local mock_config_module
local mock_logger_module
local mock_state_module
local mock_async_module

local modules_to_clear_from_cache = {
    'tungsten.core.solver',
    'tungsten.core.engine',
    'tungsten.util.async',
    'tungsten.config',
    'tungsten.state',
    'tungsten.util.logger',
}

local function clear_modules_from_cache_func()
    for _, name in ipairs(modules_to_clear_from_cache) do
        package.loaded[name] = nil
    end
end

describe("tungsten.core.solver", function()
    local original_require

    before_each(function()
        clear_modules_from_cache_func()

        mock_evaluator_module = {
            substitute_persistent_vars = spy.new(function(wolfram_str)
                return wolfram_str
            end)
        }
        mock_config_module = {
            wolfram_path = "mock_wolframscript_path",
            debug = false,
            wolfram_timeout_ms = 5000,
        }
        mock_logger_module = {
            levels = { ERROR = 1, WARN = 2, INFO = 3, DEBUG = 4 },
            notify = spy.new(function() end)
        }
        mock_state_module = {
            persistent_variables = {},
            active_jobs = {}
        }
        mock_async_module = {
            run_job = spy.new(function(cmd, key, cb)
                cb(0, "{{x -> 1}}", "")
            end)
        }

        original_require = _G.require
        _G.require = function(module_path)
            if module_path == 'tungsten.core.engine' then return mock_evaluator_module end
            if module_path == 'tungsten.config' then return mock_config_module end
            if module_path == 'tungsten.util.logger' then return mock_logger_module end
            if module_path == 'tungsten.state' then return mock_state_module end
            if module_path == 'tungsten.util.async' then return mock_async_module end
            if package.loaded[module_path] then return package.loaded[module_path] end
            return original_require(module_path)
        end
        
        solver = require("tungsten.core.solver")
    end)

    after_each(function()
        _G.require = original_require
        clear_modules_from_cache_func()
    end)

    describe("M.solve_equation_async(eq_wolfram_strs, var_wolfram_strs, is_system, callback)", function()
        local callback_spy

        before_each(function()
            callback_spy = spy.new(function() end)
        end)

        it("should correctly form Wolfram command for a single equation", function()
            solver.solve_equation_async({"x+1==2"}, {"x"}, false, callback_spy)
            assert.spy(mock_async_module.run_job).was.called(1)
            local job_args = mock_async_module.run_job.calls[1].vals[1]
            assert.are.same({ "mock_wolframscript_path", "-code", "ToString[TeXForm[Solve[{x+1==2}, {x}]], CharacterEncoding -> \"UTF8\"]" }, job_args)
        end)

        it("should correctly form Wolfram command for a system of equations", function()
            solver.solve_equation_async({"x+y==3", "x-y==1"}, {"x","y"}, true, callback_spy)
            assert.spy(mock_async_module.run_job).was.called(1)
            local job_args = mock_async_module.run_job.calls[1].vals[1]
            assert.are.same({ "mock_wolframscript_path", "-code", "ToString[TeXForm[Solve[{x+y==3, x-y==1}, {x, y}]], CharacterEncoding -> \"UTF8\"]" }, job_args)
        end)
        
        it("should log Wolfram command if debug is true", function()
            mock_config_module.debug = true
            solver = require("tungsten.core.solver")
            solver.solve_equation_async({"dbg==1"}, {"dbg"}, false, callback_spy)
            assert.spy(mock_logger_module.notify).was.called_with(
                "TungstenSolve: Wolfram command: Solve[{dbg==1}, {dbg}]",
                mock_logger_module.levels.DEBUG,
                { title = "Tungsten Debug" }
            )
        end)

        it("should handle successful job execution and parse single solution (e.g. {{x -> 1}})", function()
            mock_async_module.run_job = spy.new(function(cmd, key, cb)
                cb(0, "{{x -> 1}}", "")
            end)
            solver.solve_equation_async({"x==1"}, {"x"}, false, callback_spy)
            assert.spy(callback_spy).was.called_with("1", nil)
        end)

        it("should handle successful job execution and parse system solution (e.g. {{x -> 1, y -> 2}})", function()
            mock_async_module.run_job = spy.new(function(cmd, key, cb)
                cb(0, "{{x -> 1, y -> 2}}", "")
            end)
            solver.solve_equation_async({"x==1", "y==2"}, {"x","y"}, true, callback_spy)
            assert.spy(callback_spy).was.called_with("x = 1, y = 2", nil)
        end)

        it("should callback with error if jobstart returns 0 (invalid args)", function()
            mock_async_module.run_job = spy.new(function(cmd, key, cb)
                cb(127, "", "Jobstart failed: Invalid arguments")
            end)
            solver.solve_equation_async({"x==1"}, {"x"}, false, callback_spy)
            assert.spy(callback_spy).was.called_with(nil, match.is_string())
        end)

        it("should callback with error if jobstart returns -1 (cmd not found)", function()
            mock_async_module.run_job = spy.new(function(cmd, key, cb)
                cb(-1, "", "Command not found")
            end)
            solver.solve_equation_async({"x==1"}, {"x"}, false, callback_spy)
            assert.spy(callback_spy).was.called_with(nil, match.is_string())
        end)

        it("should use default timeout if config.wolfram_timeout_ms is nil", function()
            mock_config_module.wolfram_timeout_ms = nil
            
            package.loaded['tungsten.util.async'] = nil
            local reloaded_async = require('tungsten.util.async')
            
            reloaded_async.run_job = spy.new(function(cmd, key, cb)
                cb(0, "{{x -> 1}}", "")
            end)

            local reloaded_solver = require('tungsten.core.solver')

            reloaded_solver.solve_equation_async({"def_timeout==1"}, {"def_timeout"}, false, callback_spy)

            assert.is_nil(mock_config_module.wolfram_timeout_ms)
            assert.spy(callback_spy).was.called()
        end)
    end)
end)
