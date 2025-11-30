local spy = require("luassert.spy")
local match = require("luassert.match")

local mock_utils = require("tests.helpers.mock_utils")

describe("tungsten.core.workflow.run", function()
	local workflow
	local mock_selection_module
	local mock_event_bus_module
	local mock_error_handler_module
	local event_bus_emit_spy
	local error_handler_notify_spy

	local function load_workflow()
		mock_utils.reset_modules({ "tungsten.core.workflow" })

		package.loaded["tungsten.util.selection"] = mock_selection_module
		package.loaded["tungsten.event_bus"] = mock_event_bus_module
		package.loaded["tungsten.util.error_handler"] = mock_error_handler_module

		workflow = require("tungsten.core.workflow")
	end

	before_each(function()
		mock_selection_module = {
			create_selection_extmarks = function()
				return nil, "start-mark", "end-mark", "mode"
			end,
		}
		mock_event_bus_module = { emit = function() end }
		mock_error_handler_module = { notify_error = function() end }

		event_bus_emit_spy = spy.on(mock_event_bus_module, "emit")
		error_handler_notify_spy = spy.on(mock_error_handler_module, "notify_error")

		load_workflow()
	end)

	after_each(function()
		mock_utils.reset_modules({
			"tungsten.core.workflow",
			"tungsten.util.selection",
			"tungsten.event_bus",
			"tungsten.util.error_handler",
		})
	end)

	it("notifies errors from the input handler parse step", function()
		local definition = {
			description = "Definition description",
			input_handler = function()
				return nil, "raw text", "parse failure"
			end,
			task_handler = function() end,
		}

		workflow.run(definition)

		assert.spy(error_handler_notify_spy).was.called_with("Definition description", "parse failure")
		assert.spy(event_bus_emit_spy).was_not.called()
	end)

	it("returns early when the input handler does not produce an AST", function()
		local definition = {
			description = "Nil AST",
			input_handler = function()
				return nil, "raw text", nil
			end,
			task_handler = function() end,
		}

		workflow.run(definition)

		assert.spy(error_handler_notify_spy).was_not.called()
		assert.spy(event_bus_emit_spy).was_not.called()
	end)

	it("emits result_ready with selection details when the task completes successfully", function()
		local definition = {
			description = "Successful run",
			separator = "::",
			input_handler = function()
				return { ast = true }, "selected text", nil
			end,
			task_handler = function(_, _, callback)
				callback("result-payload")
			end,
		}

		workflow.run(definition)

		assert.spy(event_bus_emit_spy).was.called_with(
			"result_ready",
			match.same({
				result = "result-payload",
				start_mark = "start-mark",
				end_mark = "end-mark",
				selection_text = "selected text",
				mode = "mode",
				separator = "::",
			})
		)
		assert.spy(error_handler_notify_spy).was_not.called()
	end)

	it("ignores empty callback results", function()
		local definition = {
			description = "Empty result",
			input_handler = function()
				return { ast = true }, "selected text", nil
			end,
			task_handler = function(_, _, callback)
				callback(nil)
				callback("")
			end,
		}

		workflow.run(definition)

		assert.spy(event_bus_emit_spy).was_not.called()
		assert.spy(error_handler_notify_spy).was_not.called()
	end)

	it("notifies errors returned through the callback", function()
		local definition = {
			description = "Callback error",
			input_handler = function()
				return { ast = true }, "selected text", nil
			end,
			task_handler = function(_, _, callback)
				callback(nil, "callback error message")
			end,
		}

		workflow.run(definition)

		assert.spy(error_handler_notify_spy).was.called_with("Callback error", "callback error message")
		assert.spy(event_bus_emit_spy).was_not.called()
	end)

	it("reports pcall errors when the task handler raises", function()
		local definition = {
			description = "pcall failure",
			input_handler = function()
				return { ast = true }, "selected text", nil
			end,
			task_handler = function()
				error("task handler explosion")
			end,
		}

		workflow.run(definition)

		assert.spy(error_handler_notify_spy).was.called_with("pcall failure", match.has_match("task handler explosion"))
		assert.spy(event_bus_emit_spy).was_not.called()
	end)
end)
