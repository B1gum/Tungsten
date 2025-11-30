local stub = require("luassert.stub")
local mock_utils = require("tests.helpers.mock_utils")

local function build_common_mocks(renderer_result)
	local render = mock_utils.mock_module(
		"tungsten.core.render",
		{ render = stub.new({}, "render", function()
			return renderer_result
		end) }
	)

	local registry = mock_utils.mock_module("tungsten.core.registry", {
		get_handlers = function()
			return { handled = true }
		end,
		register_handlers = stub.new({}, "register_handlers"),
		reset_handlers = stub.new({}, "reset_handlers"),
	})

	local logger = mock_utils.mock_module("tungsten.util.logger", {
		debug = stub.new({}, "debug"),
		info = stub.new({}, "info"),
		warn = stub.new({}, "warn"),
		error = stub.new({}, "error"),
	})

	mock_utils.mock_module("tungsten.util.async", {
		run_job = stub.new({}, "run_job", function() end),
	})

	return render, registry, logger
end

describe("backend executors", function()
	describe("python", function()
		local executor
		local async
		local handlers

		before_each(function()
			mock_utils.reset_modules({
				"tungsten.backends.python.executor",
				"tungsten.backends.python.handlers",
				"tungsten.util.async",
				"tungsten.util.logger",
				"tungsten.core.render",
				"tungsten.core.registry",
				"tungsten.config",
				"tungsten.backends.python.python_solution",
			})

			local render = build_common_mocks("x + y")
			handlers = mock_utils.mock_module("tungsten.backends.python.handlers", {
				ensure_handlers = stub.new({}, "ensure_handlers"),
			})
			async = require("tungsten.util.async")
			mock_utils.mock_module("tungsten.config", { numeric_mode = false, backend_opts = {} })
			mock_utils.mock_module("tungsten.backends.python.python_solution", {
				parse_python_solution = stub.new({}, "parse_python_solution", function(output, vars)
					return { ok = true, formatted = table.concat(vars, ",") .. "=" .. output }
				end),
			})

			executor = require("tungsten.backends.python.executor")
			executor._test_render_module = render
		end)

		it("returns helpful errors when rendering cannot proceed", function()
			local render = require("tungsten.core.render")
			render.render = function()
				return { error = true, message = "missing handler", node_type = "binary" }
			end

			assert.equals("Error: AST is nil", executor.ast_to_code(nil))

			local registry = require("tungsten.core.registry")
			registry.get_handlers = function()
				return {}
			end
			assert.matches("No Python handlers", executor.ast_to_code({}))

			registry.get_handlers = function()
				return { handler = true }
			end
			assert.matches("Error: AST rendering failed: missing handler %(Node type: binary%)", executor.ast_to_code({}))
		end)

		it("wraps expressions and surfaces interpreter failures", function()
			local cb_result, cb_err
			mock_utils.mock_module("tungsten.config", { numeric_mode = true, backend_opts = { python = {} } })

			async.run_job:revert()
			async.run_job = stub.new(async, "run_job", function(cmd, opts)
				opts.on_exit(127, "", "boom")
				return cmd, opts
			end)

			executor.evaluate_async({ test = true }, {}, function(res, err)
				cb_result, cb_err = res, err
			end)

			assert.is_nil(cb_result)
			assert.matches("Python interpreter not found", cb_err)
			assert.truthy(async.run_job.calls[1].refs[1][2])
		end)

		it("allows overriding generated code and parsing solutions", function()
			async.run_job:revert()
			async.run_job = stub.new(async, "run_job", function(_cmd, opts)
				opts.on_exit(0, "42", "")
			end)

			local res
			executor.evaluate_async({ something = true }, { code = "custom" }, function(stdout)
				res = stdout
			end)
			assert.equals("42", res)

			local solve_res, solve_err
			local original_ast_to_code = executor.ast_to_code
			executor.ast_to_code = function(node)
				return node and node.name or "expr"
			end
			executor.solve_async({ variables = { { name = "x" } } }, {}, function(r, e)
				solve_res, solve_err = r, e
			end)
			executor.ast_to_code = original_ast_to_code

			assert.is_nil(solve_err)
			assert.equals("x=42", solve_res)
			assert.stub(handlers.ensure_handlers).was.called()
		end)
	end)

	describe("wolfram", function()
		local executor
		local async
		local handlers

		before_each(function()
			mock_utils.reset_modules({
				"tungsten.backends.wolfram.executor",
				"tungsten.backends.wolfram.handlers",
				"tungsten.util.async",
				"tungsten.util.logger",
				"tungsten.core.render",
				"tungsten.core.registry",
				"tungsten.config",
				"tungsten.backends.wolfram.wolfram_solution",
			})

			build_common_mocks("f[x]")
			handlers = mock_utils.mock_module("tungsten.backends.wolfram.handlers", {
				ensure_handlers = stub.new({}, "ensure_handlers"),
			})
			async = require("tungsten.util.async")
			mock_utils.mock_module("tungsten.config", { numeric_mode = false, backend_opts = {} })
			mock_utils.mock_module("tungsten.backends.wolfram.wolfram_solution", {
				parse_wolfram_solution = stub.new({}, "parse_wolfram_solution", function()
					return { ok = true, formatted = "solution" }
				end),
			})

			executor = require("tungsten.backends.wolfram.executor")
		end)

		it("formats errors from render failures and missing handlers", function()
			local render = require("tungsten.core.render")
			render.render = function()
				return { error = true, message = "missing handler" }
			end

			assert.equals("Error: AST is nil", executor.ast_to_code(nil))

			local registry = require("tungsten.core.registry")
			registry.get_handlers = function()
				return {}
			end
			assert.matches("No Wolfram handlers", executor.ast_to_code({}))

			registry.get_handlers = function()
				return { ok = true }
			end
			assert.matches("AST rendering failed: missing handler", executor.ast_to_code({}))
		end)

		it("wraps numeric expressions and surfaces interpreter errors", function()
			async.run_job:revert()
			async.run_job = stub.new(async, "run_job", function(_cmd, opts)
				opts.on_exit(5, "stdout", "stderr")
			end)

			local res, err
			executor.evaluate_async({ node = true }, { numeric = true }, function(r, e)
				res, err = r, e
			end)

			assert.is_nil(res)
			assert.matches("WolframScript exited with code 5", err)
		end)

		it("parses solutions returned by evaluate_async", function()
			async.run_job:revert()
			async.run_job = stub.new(async, "run_job", function(_cmd, opts)
				opts.on_exit(0, "{x -> 7}", "")
			end)

			local result, err
			executor.solve_async({ variables = { { name = "x" } } }, {}, function(r, e)
				result, err = r, e
			end)

			assert.is_nil(err)
			assert.equals("solution", result)
			assert.stub(handlers.ensure_handlers).was.called()
		end)
	end)
end)
