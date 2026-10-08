local parser = require("tungsten.core.parser")
require("tungsten.core")
local functions = require("tungsten.core.function_definitions")
local config = require("tungsten.config")

describe("function definition evaluation", function()
	local saved, engine, backend, selected_text, persistent, clears
	local dependencies = {
		"tungsten.core.engine",
		"tungsten.core.solver",
		"tungsten.core.command_definitions",
		"tungsten.backends.manager",
		"tungsten.state",
		"tungsten.core.cache_service",
		"tungsten.core.job_coordinator",
		"tungsten.util.selection",
		"tungsten.util.commands",
		"tungsten.core.persistent_vars",
	}

	before_each(function()
		functions.clear()
		saved = {}
		for _, name in ipairs(dependencies) do
			saved[name] = package.loaded[name]
		end
		persistent = config.backend_opts.wolfram.persistent
		config.backend_opts.wolfram.persistent = false
		clears = 0
		backend = {
			ast_to_code = function(node)
				backend.rendered_ast = node
				return "expanded-code"
			end,
			evaluate_async = function(_, _, callback)
				callback("25", nil)
			end,
			evaluate_persistent = function(_, _, callback)
				callback("25", nil)
			end,
		}
		package.loaded["tungsten.backends.manager"] = {
			current = function()
				return backend
			end,
		}
		package.loaded["tungsten.state"] = { active_backend = "wolfram", persistent_variables = {} }
		package.loaded["tungsten.core.cache_service"] = {
			get_cache_key = function(code)
				return code
			end,
			should_use_cache = function()
				return false
			end,
			try_get = function()
				return false
			end,
			clear = function()
				clears = clears + 1
			end,
		}
		package.loaded["tungsten.core.job_coordinator"] = {
			is_job_already_running = function()
				return false
			end,
		}
		package.loaded["tungsten.util.selection"] = {
			get_visual_selection = function()
				return selected_text
			end,
		}
		package.loaded["tungsten.util.commands"] = {}
		package.loaded["tungsten.core.persistent_vars"] = {}
		package.loaded["tungsten.core.engine"] = nil
		package.loaded["tungsten.core.solver"] = nil
		package.loaded["tungsten.core.command_definitions"] = nil
		engine = require("tungsten.core.engine")
	end)

	after_each(function()
		functions.clear()
		config.backend_opts.wolfram.persistent = persistent
		for _, name in ipairs(dependencies) do
			package.loaded[name] = saved[name]
		end
	end)

	it("registers an evaluated definition and expands later calls in either process mode", function()
		selected_text = "f(x) = x^2"
		local evaluate = require("tungsten.core.command_definitions").TungstenEvaluate
		local body, _, err = evaluate.input_handler()
		assert.is_nil(err)
		local definition_result, completed
		evaluate.task_handler(body, false, false, function(result, definition_err)
			assert.is_nil(definition_err)
			definition_result = result
			completed = true
		end)
		assert.is_true(completed)
		assert.is_nil(definition_result)
		assert.equals(1, clears)
		for _, persistent_mode in ipairs({ false, true }) do
			config.backend_opts.wolfram.persistent = persistent_mode
			local call = parser.parse("f(5)").series[1]
			local result
			engine.evaluate_async(call, false, function(value, evaluation_err)
				assert.is_nil(evaluation_err)
				result = value
			end)
			assert.equals("25", result)
			assert.equals("superscript", backend.rendered_ast.type)
			assert.equals(5, backend.rendered_ast.base.value)
			assert.equals(2, backend.rendered_ast.exponent.value)
		end
	end)

	it("returns expansion errors before backend rendering", function()
		assert(functions.store(assert(functions.parse_definition("f(x)=x^2"))))
		local result, err
		engine.evaluate_async(parser.parse("f(1,2)").series[1], false, function(value, error_message)
			result, err = value, error_message
		end)
		assert.is_nil(result)
		assert.matches("Wrong number of arguments", err)
		assert.is_nil(backend.rendered_ast)
	end)

	it("expands defined functions in equations submitted to Solve", function()
		assert(functions.store(assert(functions.parse_definition("f(x)=x^2"))))
		local submitted
		backend.solve_async = function(node, _, callback)
			submitted = node
			callback("solution", nil)
		end
		local equation = parser.parse("f(x)=25").series[1]
		local variable = { type = "variable", name = "x" }
		require("tungsten.core.solver").solve_asts_async({ equation }, { variable }, false, function(_, err)
			assert.is_nil(err)
		end)
		assert.equals("superscript", submitted.equations[1].lhs.type)
		assert.equals("x", submitted.equations[1].lhs.base.name)
	end)
end)
