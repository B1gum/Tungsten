-- tests/unit/core/solver_spec.lua
-- Unit tests for the Tungsten equation solver.

local spy = require("luassert.spy")
local mock_utils = require("tests.helpers.mock_utils")

local solver
local solution_helper

local mock_evaluator_module
local mock_wolfram_backend

local modules_to_clear_from_cache = {
	"tungsten.core.solver",
	"tungsten.core.engine",
	"tungsten.backends.wolfram",
}

describe("tungsten.core.solver", function()
	local original_require

	before_each(function()
		mock_utils.reset_modules(modules_to_clear_from_cache)

		mock_evaluator_module = {
			solve_async = spy.new(function(ast_node, opts, cb)
				if cb then
					cb("{{x -> 1}}", nil)
				end
			end),
		}

		mock_wolfram_backend = {
			ast_to_wolfram = spy.new(function(node)
				return node.name or node.id or ""
			end),
		}

		original_require = _G.require
		_G.require = function(module_path)
			if module_path == "tungsten.core.engine" then
				return mock_evaluator_module
			end
			if module_path == "tungsten.backends.wolfram" then
				return mock_wolfram_backend
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
	end)

	describe("solve_asts_async", function()
		local callback_spy

		before_each(function()
			callback_spy = spy.new(function() end)
		end)

		it("calls engine.solve_async with constructed solve AST and parses result", function()
			local eq_ast = { type = "equation", id = "eq" }
			local var_ast = { type = "variable", name = "x" }

			solver.solve_asts_async({ eq_ast }, { var_ast }, false, callback_spy)

			assert.spy(mock_evaluator_module.solve_async).was.called(1)
			local passed_ast = mock_evaluator_module.solve_async.calls[1].vals[1]
			assert.are.equal("solve_system", passed_ast.type)
			assert.are.same({ eq_ast }, passed_ast.equations)
			assert.are.same({ var_ast }, passed_ast.variables)
			assert.spy(callback_spy).was.called_with("x = 1", nil)
		end)

		it("propagates errors from engine.solve_async", function()
			mock_evaluator_module.solve_async = spy.new(function(_, _, cb)
				cb(nil, "fail")
			end)

			local eq_ast = { type = "equation", id = "eq" }
			local var_ast = { type = "variable", name = "x" }

			solver.solve_asts_async({ eq_ast }, { var_ast }, false, callback_spy)
			assert.spy(callback_spy).was.called_with(nil, "fail")
		end)
	end)
end)
