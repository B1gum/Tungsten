local spy = require("luassert.spy")
local mock_utils = require("tests.helpers.mock_utils")

describe("Linear Algebra command definitions", function()
	local command_definitions
	local mock_cmd_utils
	local mock_ast
	local mock_evaluator
	local mock_config

	local modules_to_reset = {
		"tungsten.domains.linear_algebra.command_definitions",
	}

	local original_require

	before_each(function()
		mock_cmd_utils = {}
		mock_ast = {}
		mock_evaluator = {}
		mock_config = { numeric_mode = true }

		mock_cmd_utils.parse_selected_latex = spy.new(function()
			return nil, nil, nil
		end)

		mock_ast.create_gauss_eliminate_node = spy.new(function(node)
			return { type = "gauss", node = node }
		end)
		mock_ast.create_linear_independent_test_node = spy.new(function(node)
			return { type = "lint", node = node }
		end)
		mock_ast.create_rank_node = spy.new(function(node)
			return { type = "rank", node = node }
		end)
		mock_ast.create_eigenvalues_node = spy.new(function(node)
			return { type = "eigenvalues", node = node }
		end)
		mock_ast.create_eigenvectors_node = spy.new(function(node)
			return { type = "eigenvectors", node = node }
		end)
		mock_ast.create_eigensystem_node = spy.new(function(node)
			return { type = "eigensystem", node = node }
		end)

		mock_evaluator.evaluate_async = spy.new(function(ast_node, numeric_mode, cb)
			if cb then
				cb(ast_node, nil)
			end
		end)

		original_require = _G.require
		_G.require = function(module_path)
			if module_path == "tungsten.util.commands" then
				return mock_cmd_utils
			end
			if module_path == "tungsten.core.ast" then
				return mock_ast
			end
			if module_path == "tungsten.core.engine" then
				return mock_evaluator
			end
			if module_path == "tungsten.config" then
				return mock_config
			end
			return original_require(module_path)
		end

		mock_utils.reset_modules(modules_to_reset)
		command_definitions = require("tungsten.domains.linear_algebra.command_definitions")
	end)

	after_each(function()
		_G.require = original_require
		mock_utils.reset_modules(modules_to_reset)
	end)

	local function expect_successful_matrix_parse(definition)
		local node = { type = "matrix" }
		mock_cmd_utils.parse_selected_latex = spy.new(function()
			return node, "A", nil
		end)

		local parsed_node, parsed_text, err = definition.input_handler()

		assert.spy(mock_cmd_utils.parse_selected_latex).was.called_with("matrix")
		assert.is_nil(err)
		assert.are.equal(node, parsed_node)
		assert.are.equal("A", parsed_text)
	end

	it("validates GaussEliminate workflow", function()
		expect_successful_matrix_parse(command_definitions.TungstenGaussEliminate)

		local node = { type = "matrix" }
		local args = command_definitions.TungstenGaussEliminate.prepare_args(node)
		assert.same({ type = "gauss", node = node }, args[1])
		assert.is_true(args[2])
		assert.spy(mock_ast.create_gauss_eliminate_node).was.called_with(node)

		local cb = spy.new(function() end)
		command_definitions.TungstenGaussEliminate.task_handler(args[1], args[2], cb)
		assert.spy(mock_evaluator.evaluate_async).was.called_with(args[1], args[2], cb)
	end)

	it("handles missing or invalid GaussEliminate selections", function()
		mock_cmd_utils.parse_selected_latex = spy.new(function()
			return nil, nil, nil
		end)

		local node, text, err = command_definitions.TungstenGaussEliminate.input_handler()
		assert.is_nil(node)
		assert.is_nil(text)
		assert.is_nil(err)

		mock_cmd_utils.parse_selected_latex = spy.new(function()
			return { type = "vector" }, "v", nil
		end)

		node, text, err = command_definitions.TungstenGaussEliminate.input_handler()
		assert.is_nil(node)
		assert.is_not_nil(err)
		assert.is_nil(text)
	end)

	describe("LinearIndependent result handling", function()
		local result_handler

		before_each(function()
			result_handler = command_definitions.TungstenLinearIndependent.task_handler
		end)

		it("normalizes boolean-ish string results", function()
			local cb = spy.new(function() end)
			mock_evaluator.evaluate_async = function(_, _, inner_cb)
				inner_cb("\\text{True}", nil)
				inner_cb("False", nil)
			end

			result_handler({ type = "lint" }, false, cb)

			assert.spy(cb).was.called_with("True", nil)
			assert.spy(cb).was.called_with("False", nil)
		end)

		it("wraps unexpected results", function()
			local cb = spy.new(function() end)
			mock_evaluator.evaluate_async = function(_, _, inner_cb)
				inner_cb("maybe", nil)
				inner_cb(42, nil)
				inner_cb(nil, nil)
			end

			result_handler({ type = "lint" }, false, cb)

			assert.spy(cb).was.called_with("Undetermined (maybe)", nil)
			assert.spy(cb).was.called_with("Undetermined (42)", nil)
			assert.spy(cb).was.called_with(nil, nil)
		end)

		it("propagates evaluator errors", function()
			local cb = spy.new(function() end)
			local err = { message = "boom" }
			mock_evaluator.evaluate_async = function(_, _, inner_cb)
				inner_cb(nil, err)
			end

			result_handler({ type = "lint" }, false, cb)
			assert.spy(cb).was.called_with(nil, err)
		end)
	end)

	it("validates LinearIndependent input and prepare/task handlers", function()
		mock_cmd_utils.parse_selected_latex = spy.new(function()
			return { type = "vector_list" }, "vecs", nil
		end)

		local node, text, err = command_definitions.TungstenLinearIndependent.input_handler()
		assert.is_nil(err)
		assert.are.equal("vecs", text)
		assert.are.equal("vector_list", node.type)

		local args = command_definitions.TungstenLinearIndependent.prepare_args(node)
		assert.same({ type = "lint", node = node }, args[1])
		assert.is_false(args[2])
		assert.spy(mock_ast.create_linear_independent_test_node).was.called_with(node)

		local cb = spy.new(function() end)
		command_definitions.TungstenLinearIndependent.task_handler(args[1], args[2], cb)
		assert.spy(mock_evaluator.evaluate_async).was.called()
	end)

	it("rejects invalid LinearIndependent selections", function()
		mock_cmd_utils.parse_selected_latex = spy.new(function()
			return { type = "not_matrix" }, "bad", nil
		end)

		local node, _, err = command_definitions.TungstenLinearIndependent.input_handler()
		assert.is_nil(node)
		assert.is_not_nil(err)
	end)

	it("handles parse errors and empty selections", function()
		mock_cmd_utils.parse_selected_latex = spy.new(function()
			return nil, nil, "parse failed"
		end)

		local node, _, err = command_definitions.TungstenGaussEliminate.input_handler()
		assert.is_nil(node)
		assert.are.equal("parse failed", err)

		mock_cmd_utils.parse_selected_latex = spy.new(function()
			return nil, nil, nil
		end)
		node, _, err = command_definitions.TungstenRank.input_handler()
		assert.is_nil(node)
		assert.is_nil(err)

		mock_cmd_utils.parse_selected_latex = spy.new(function()
			return nil, nil, "rank err"
		end)
		node, _, err = command_definitions.TungstenRank.input_handler()
		assert.is_nil(node)
		assert.are.equal("rank err", err)

		mock_cmd_utils.parse_selected_latex = spy.new(function()
			return { type = "vector" }, "r", nil
		end)
		node, _, err = command_definitions.TungstenRank.input_handler()
		assert.is_nil(node)
		assert.is_not_nil(err)

		mock_cmd_utils.parse_selected_latex = spy.new(function()
			return nil, nil, "li failed"
		end)
		node, _, err = command_definitions.TungstenLinearIndependent.input_handler()
		assert.is_nil(node)
		assert.are.equal("li failed", err)

		mock_cmd_utils.parse_selected_latex = spy.new(function()
			return nil, nil, nil
		end)
		node, _, err = command_definitions.TungstenLinearIndependent.input_handler()
		assert.is_nil(node)
		assert.is_nil(err)
	end)

	it("validates Rank command flows", function()
		expect_successful_matrix_parse(command_definitions.TungstenRank)

		local node = { type = "matrix" }
		local args = command_definitions.TungstenRank.prepare_args(node)
		assert.same({ type = "rank", node = node }, args[1])
		assert.is_true(args[2])
		assert.spy(mock_ast.create_rank_node).was.called_with(node)

		local cb = spy.new(function() end)
		command_definitions.TungstenRank.task_handler(args[1], args[2], cb)
		assert.spy(mock_evaluator.evaluate_async).was.called_with(args[1], args[2], cb)
	end)

	it("supports simple matrix-based commands (eigen variants)", function()
		local def = command_definitions.TungstenEigenvalue

		expect_successful_matrix_parse(def)

		local node = { type = "matrix" }
		local args = def.prepare_args(node)
		assert.same({ type = "eigenvalues", node = node }, args[1])
		assert.is_true(args[2])

		local cb = spy.new(function() end)
		def.task_handler(args[1], args[2], cb)
		assert.spy(mock_evaluator.evaluate_async).was.called_with(args[1], args[2], cb)

		-- Ensure other builders are exercised
		command_definitions.TungstenEigenvector.prepare_args(node)
		assert.spy(mock_ast.create_eigenvectors_node).was.called_with(node)

		command_definitions.TungstenEigensystem.prepare_args(node)
		assert.spy(mock_ast.create_eigensystem_node).was.called_with(node)
	end)

	it("propagates parse errors for eigen commands", function()
		mock_cmd_utils.parse_selected_latex = spy.new(function()
			return nil, nil, "eigen err"
		end)

		local node, _, err = command_definitions.TungstenEigenvalue.input_handler()
		assert.is_nil(node)
		assert.are.equal("eigen err", err)

		mock_cmd_utils.parse_selected_latex = spy.new(function()
			return nil, nil, nil
		end)

		node, _, err = command_definitions.TungstenEigenvalue.input_handler()
		assert.is_nil(node)
		assert.is_nil(err)
	end)

	it("rejects non-matrix input for simple matrix commands", function()
		mock_cmd_utils.parse_selected_latex = spy.new(function()
			return { type = "vector" }, "v", nil
		end)

		local _, _, err = command_definitions.TungstenEigenvalue.input_handler()
		assert.is_not_nil(err)
	end)
end)
