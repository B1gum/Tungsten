-- tests/unit/core/solver_spec.lua
-- Unit tests for the Tungsten equation solver.

local spy = require("luassert.spy")
local mock_utils = require("tests.helpers.mock_utils")

local solver
local solution_helper

local mock_backend_manager_module
local mock_backend_module

local modules_to_clear_from_cache = {
	"tungsten.core.solver",
	"tungsten.backends.manager",
}

describe("tungsten.core.solver", function()
	local original_require

	before_each(function()
		mock_utils.reset_modules(modules_to_clear_from_cache)

		mock_backend_module = {}
		function mock_backend_module.solve_async(_, node, opts, cb)
			mock_backend_module.called_with = { node, opts, cb }
			if cb then
				cb("solution", nil)
			end
		end
		mock_backend_manager_module = {
			current = function()
				return mock_backend_module
			end,
		}

		original_require = _G.require
		_G.require = function(module_path)
			if module_path == "tungsten.backends.manager" then
				return mock_backend_manager_module
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

	describe("solve_asts_async", function()
		it("invokes backend solve_async with constructed AST", function()
			local callback_spy = spy.new(function() end)

			local eq1 = { type = "equation", id = "eq1" }
			local var1 = { type = "variable", id = "v1" }

			solver.solve_asts_async({ eq1 }, { var1 }, false, callback_spy)

			assert.is_table(mock_backend_module.called_with)
			local node_arg, opts_arg, cb_arg = unpack(mock_backend_module.called_with)
			assert.are.equal("solve_system", node_arg.type)
			assert.are.equal(eq1, node_arg.equations[1])
			assert.are.equal(var1, node_arg.variables[1])
			assert.are.same({ is_system = false }, opts_arg)
			assert.are.equal(callback_spy, cb_arg)
		end)
	end)
end)
