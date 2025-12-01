local mock_utils = require("tests.helpers.mock_utils")
local stub = require("luassert.stub")
local spy = require("luassert.spy")

local modules_to_reset = {
	"tungsten.core.persistent_vars",
	"tungsten.core.parser",
	"tungsten.backends.manager",
	"tungsten.config",
	"tungsten.state",
}

describe("tungsten.core.persistent_vars", function()
	local persistent_vars
	local mock_parser
	local mock_backend
	local mock_manager
	local mock_config
	local mock_state

	before_each(function()
		mock_parser = {}
		stub.new(mock_parser, "parse")

		mock_backend = {}
		mock_manager = {
			current = function()
				return mock_backend
			end,
		}

		mock_config = {
			persistent_variable_assignment_operator = ":=",
		}
		mock_state = {}

		mock_utils.reset_modules(modules_to_reset)

		package.loaded["tungsten.core.parser"] = mock_parser
		package.loaded["tungsten.backends.manager"] = mock_manager
		package.loaded["tungsten.config"] = mock_config
		package.loaded["tungsten.state"] = mock_state

		persistent_vars = require("tungsten.core.persistent_vars")
	end)

	after_each(function()
		mock_utils.reset_modules(modules_to_reset)
	end)

	describe("parse_definition", function()
		it("returns descriptive errors for invalid selections", function()
			local name1, rhs1, err1 = persistent_vars.parse_definition(nil)
			assert.is_nil(name1)
			assert.is_nil(rhs1)
			assert.matches("No text selected", err1)

			local name2, rhs2, err2 = persistent_vars.parse_definition("foo")
			assert.is_nil(name2)
			assert.is_nil(rhs2)
			assert.matches("No assignment operator", err2)

			local _, _, err3 = persistent_vars.parse_definition(":=bar")
			assert.matches("variable name cannot be empty", err3)

			local _, _, err4 = persistent_vars.parse_definition("foo :=   ")
			assert.matches("cannot be empty", err4)
		end)

		it("trims whitespace and splits variable and rhs", function()
			local name, rhs, err = persistent_vars.parse_definition("  myVar  :=  x^2 + 1  ")
			assert.is_nil(err)
			assert.are.equal("myVar", name)
			assert.are.equal("x^2 + 1", rhs)
		end)
	end)

	describe("latex_to_backend_code", function()
		it("returns errors when parsing fails or returns multiple series", function()
			mock_parser.parse.invokes(function()
				error("boom")
			end)
			local code, err = persistent_vars.latex_to_backend_code("a", "bad", {})
			assert.is_nil(code)
			assert.matches("boom", err)

			mock_parser.parse.invokes(function()
				return { series = { {}, {} } }
			end)
			code, err = persistent_vars.latex_to_backend_code("a", "x+y", {})
			assert.is_nil(code)
			assert.matches("expected single expression", err)
		end)

		it("requires an active backend with a working ast_to_code", function()
			mock_parser.parse.invokes(function()
				return { series = { { type = "mock" } } }
			end)

			mock_manager.current = function()
				return nil
			end
			local code, err = persistent_vars.latex_to_backend_code("v", "x", {})
			assert.is_nil(code)
			assert.matches("No active backend", err)

			mock_manager.current = function()
				local backend = {}
				stub.new(backend, "ast_to_code", function()
					return { not_a_string = true }
				end)
				return backend
			end
			code, err = persistent_vars.latex_to_backend_code("v", "x", {})
			assert.is_nil(code)
			assert.matches("Failed to convert", err)

			mock_manager.current = function()
				local backend = {}
				stub.new(backend, "ast_to_code", function()
					return "a + b"
				end)
				return backend
			end
			code, err = persistent_vars.latex_to_backend_code("v", "x", {})
			assert.are.equal("a + b", code)
			assert.is_nil(err)
		end)
	end)

	describe("write_async", function()
		it("prefers backend persistent_write_async and falls back to evaluate_async", function()
			local write_args
			mock_backend.persistent_write_async = function(...)
				write_args = { ... }
			end

			local eval_args
			mock_backend.evaluate_async = function(...)
				eval_args = { ... }
			end

			persistent_vars.write_async("x", "1", nil)
			assert.are.same({ "x", "1", nil }, write_args)

			mock_backend.persistent_write_async = nil
			persistent_vars.write_async("y", "2", "cb")
			assert.are.same({ nil, { code = "y := 2" }, "cb" }, eval_args)
		end)

		it("invokes callback with an error when no backend is active", function()
			mock_manager.current = function()
				return nil
			end
			local cb = spy.new(function() end)
			persistent_vars.write_async("z", "3", cb)
			assert.spy(cb).was.called()
			assert.are.equal("No active backend", cb.calls[1].vals[2])
		end)
	end)

	describe("read_async", function()
		it("prefers backend persistent_read_async or falls back to evaluate_async", function()
			local read_args
			mock_backend.persistent_read_async = function(...)
				read_args = { ... }
			end

			local eval_args
			mock_backend.evaluate_async = function(...)
				eval_args = { ... }
			end

			local cb = spy.new(function() end)
			persistent_vars.read_async("x", cb)
			assert.are.same({ "x", cb }, read_args)

			mock_backend.persistent_read_async = nil
			persistent_vars.read_async("y", cb)
			assert.are.same({ nil, { code = "y" }, cb }, eval_args)
		end)

		it("invokes callback with an error when backend is missing", function()
			mock_manager.current = function()
				return nil
			end
			local cb = spy.new(function() end)
			persistent_vars.read_async("x", cb)
			assert.spy(cb).was.called()
			assert.are.equal("No active backend", cb.calls[1].vals[2])
		end)
	end)

	describe("store", function()
		it("persists variables in state and writes them via backend", function()
			mock_state.persistent_variables = {}
			local write_spy = spy.on(persistent_vars, "write_async").call_fake(function() end)

			persistent_vars.store("a", "def", nil)
			assert.are.equal("def", mock_state.persistent_variables.a)
			assert.spy(write_spy).was.called_with("a", "def", nil)
		end)
	end)
end)
