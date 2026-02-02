local spy = require("luassert.spy")
local stub = require("luassert.stub")
local mock_utils = require("tests.helpers.mock_utils")
local wait_for = require("tests.helpers.wait").wait_for

local function collect_upvalues(func)
	local map = {}
	local i = 1
	while true do
		local n, v = debug.getupvalue(func, i)
		if not n then
			break
		end
		map[n] = v
		i = i + 1
	end
	return map
end

describe("tungsten util additional coverage", function()
	local original_vim

	before_each(function()
		original_vim = _G.vim
	end)

	after_each(function()
		_G.vim = original_vim
		mock_utils.reset_modules({
			"tungsten.util.async",
			"tungsten.util.commands",
			"tungsten.util.error_handler",
			"tungsten.util.insert_result",
			"tungsten.util.logger",
			"tungsten.util.selection",
			"tungsten.util.plotting.job_submit",
			"tungsten.util.ast_format",
			"tungsten.domains.plotting.workflow.backend_command",
			"tungsten.domains.plotting.io",
			"tungsten.domains.plotting.job_manager",
			"tungsten.ui.float_result",
		})
		package.loaded["plenary.job"] = nil
	end)

	it("covers async queue cancellation and pending cancel attachment", function()
		local async = require("tungsten.util.async")
		local config = require("tungsten.config")
		local state = require("tungsten.state")

		local original_schedule = _G.vim.schedule
		_G.vim.schedule = function(fn)
			fn()
		end

		state.active_jobs = {}
		local original_max_jobs = config.max_jobs
		config.max_jobs = 0

		local run_job_upvalues = collect_upvalues(async.run_job)
		local job_queue = run_job_upvalues.job_queue
		local create_proxy_handle = run_job_upvalues.create_proxy_handle
		local spawn_process = run_job_upvalues.spawn_process

		local process_queue = collect_upvalues(spawn_process).process_queue
		local attach_real_handle = collect_upvalues(process_queue).attach_real_handle

		assert.is_function(create_proxy_handle)
		assert.is_function(job_queue.remove)
		assert.is_function(attach_real_handle)

		local on_exit = spy.new(function() end)
		local proxy = create_proxy_handle({ on_exit = on_exit })
		job_queue:enqueue({ "cmd" }, {}, proxy)

		assert.is_true(proxy.is_active())
		proxy.cancel()
		assert.spy(on_exit).was_called()
		local args = on_exit.calls[1].vals
		assert.are.equal(-1, args[1])
		assert.are.equal("", args[2])
		assert.are.equal("", args[3])
		assert.is_table(args[4])
		assert.are.equal("cancelled", args[4].cancel_reason)
		assert.is_false(proxy.is_active())
		assert.is_false(job_queue:remove(proxy))

		attach_real_handle(nil, {})

		local real_cancel = spy.new(function() end)
		local proxy2 = create_proxy_handle({})
		proxy2._pending_cancel = true
		attach_real_handle(proxy2, { cancel = real_cancel, id = 99 })
		assert.spy(real_cancel).was_called()
		assert.are.equal(99, proxy2.id)

		config.max_jobs = original_max_jobs
		_G.vim.schedule = original_schedule
	end)

	it("covers async handle lifecycle with mocked job", function()
		local config = require("tungsten.config")
		local original_max_jobs = config.max_jobs
		config.max_jobs = math.huge
		local state = require("tungsten.state")
		state.active_jobs = {}

		local original_schedule = _G.vim.schedule
		_G.vim.schedule = function(fn)
			fn()
		end

		local exit_cb
		local job_instance
		local JobMock = {}
		function JobMock.new(_, opts)
			exit_cb = opts.on_exit
			job_instance = {
				pid = 7,
				start = function(_) end,
				shutdown = function() end,
				result = function()
					return { "out" }
				end,
				stderr_result = function()
					return { "err" }
				end,
			}

			return job_instance
		end

		package.loaded["plenary.job"] = JobMock

		local async = require("tungsten.util.async")
		local result
		local handle = async.run_job({ "cmd" }, {
			timeout = 5,
			on_exit = function(code, stdout, stderr)
				result = { code = code, out = stdout, err = stderr }
			end,
		})

		assert.is_true(handle.is_active())
		exit_cb(job_instance, 0)
		wait_for(function()
			return result ~= nil
		end, 1000)

		assert.are.same({ code = 0, out = "out", err = "err" }, result)
		handle.cancel()
		assert.is_false(handle.is_active())

		config.max_jobs = original_max_jobs
		_G.vim.schedule = original_schedule
	end)

	it("exercises util.commands parse error branches", function()
		local selection_mock = mock_utils.mock_module("tungsten.util.selection", {
			get_visual_selection = function()
				return ""
			end,
		})
		local parser_module = mock_utils.mock_module("tungsten.core.parser", {
			parse = function()
				return { series = { 1 } }
			end,
		})

		local commands = require("tungsten.util.commands")
		local ast, text, err = commands.parse_selected_latex("expression")
		assert.is_nil(ast)
		assert.is_nil(text)
		assert.are.equal("No expression selected.", err)

		selection_mock.get_visual_selection = function()
			return "x"
		end
		parser_module.parse = function()
			error("parse fail")
		end

		ast, text, err = commands.parse_selected_latex("expression")
		assert.is_nil(ast)
		assert.is_nil(text)
		assert.matches("parse fail", err)

		parser_module.parse = function()
			return { series = { 1, 2 } }
		end

		ast, text, err = commands.parse_selected_latex("expression")
		assert.is_nil(ast)
		assert.are.equal("x", text)
		assert.are.equal("Selection must contain a single expression", err)
	end)

	it("formats error handler positions and falls back when notify missing", function()
		local error_handler = require("tungsten.util.error_handler")
		local original_notify = _G.vim.notify
		_G.vim.notify = nil

		local formatted = error_handler.format_line_col("a\nabc", 4)
		assert.are.equal("line 2, column 2", formatted)

		local printed = ""
		local original_print = _G.print
		_G.print = function(msg)
			printed = msg
		end

		error_handler.notify_error("ctx", error_handler.E_TIMEOUT, 4, "a\nabc", "details")
		assert.is_truthy(printed:match("line 2, column 2"))

		_G.print = original_print
		_G.vim.notify = original_notify
	end)

	it("covers insert_result edge cases", function()
		local insert_result = require("tungsten.util.insert_result")
		require("tungsten.state")
		local config = require("tungsten.config")

		local original_display = config.result_display
		local original_separator = config.result_separator
		config.result_display = "inline"
		config.result_separator = ""

		local original_get_extmark = _G.vim.api.nvim_buf_get_extmark_by_id
		local original_get_lines = _G.vim.api.nvim_buf_get_lines
		local original_get_text = _G.vim.api.nvim_buf_get_text
		local original_set_text = _G.vim.api.nvim_buf_set_text

		_G.vim.api.nvim_buf_get_extmark_by_id = function()
			return nil
		end

		local s, e = insert_result._resolve_positions(1, 2, "V")
		assert.is_nil(s)
		assert.is_nil(e)

		_G.vim.api.nvim_buf_get_extmark_by_id = original_get_extmark
		_G.vim.api.nvim_buf_get_lines = function()
			return { "short" }
		end
		_G.vim.api.nvim_buf_get_text = function()
			return { "line" }
		end
		_G.vim.api.nvim_buf_set_text = function() end

		local bufnr, start_line_api, start_col_api, end_line_api, end_col_api = insert_result._compute_range(
			{ 0, 1, 5 },
			{ 0, 1, 2 },
			nil
		)
		assert.are.equal(0, bufnr)
		assert.are.equal(0, start_line_api)
		assert.are.equal(4, start_col_api)
		assert.are.equal(0, end_line_api)
		assert.are.equal(4, end_col_api)

		config.result_display = "float"
		local float_module = mock_utils.mock_module("tungsten.ui.float_result", { show = function() end })
		local hook_spy = stub(require("tungsten"), "_execute_hook")
		local event_spy = stub(require("tungsten"), "_emit_result_event")

		insert_result.insert_result("", nil, { 0, 1, 1 }, { 0, 1, 1 }, "lhs")
		assert.spy(float_module.show).was_called()
		hook_spy:revert()
		event_spy:revert()

		config.result_display = original_display
		config.result_separator = original_separator
		_G.vim.api.nvim_buf_get_extmark_by_id = original_get_extmark
		_G.vim.api.nvim_buf_get_lines = original_get_lines
		_G.vim.api.nvim_buf_get_text = original_get_text
		_G.vim.api.nvim_buf_set_text = original_set_text
	end)

	it("covers logger getters and fallback notify", function()
		local logger = require("tungsten.util.logger")
		local original_notify = _G.vim.notify
		_G.vim.notify = nil

		assert.is_number(logger.get_level())

		local printed = ""
		local original_print = _G.print
		_G.print = function(msg)
			printed = msg
		end

		logger.notify("message", logger.levels.WARN, { title = "Title" })
		assert.matches("Title", printed)

		_G.print = original_print
		_G.vim.notify = original_notify
	end)

	it("covers selection extmark clamping and virtual mode", function()
		local selection = require("tungsten.util.selection")
		local original_getpos = _G.vim.fn.getpos
		local original_mode = _G.vim.fn.mode
		local original_line_count = _G.vim.api.nvim_buf_line_count
		local original_get_lines = _G.vim.api.nvim_buf_get_lines
		local original_set_extmark = _G.vim.api.nvim_buf_set_extmark

		_G.vim.fn.getpos = function(mark)
			if mark == "'<" then
				return { 0, -1, -2, 0 }
			end
			return { 0, 5, 10, 0 }
		end
		_G.vim.fn.mode = function()
			return "V"
		end
		_G.vim.api.nvim_buf_line_count = function()
			return 0
		end
		_G.vim.api.nvim_buf_get_lines = function()
			return { "edge" }
		end
		_G.vim.api.nvim_buf_set_extmark = function(_, ns, line, col)
			return ns + line + col
		end

		local _, _, _, mode = selection.create_selection_extmarks()
		assert.are.equal("V", mode)

		_G.vim.fn.getpos = function()
			return { 0, 2, -1, 0 }
		end
		_G.vim.api.nvim_buf_get_text = function()
			return {}
		end
		assert.are.equal("", selection.get_visual_selection())

		_G.vim.fn.getpos = original_getpos
		_G.vim.fn.mode = original_mode
		_G.vim.api.nvim_buf_line_count = original_line_count
		_G.vim.api.nvim_buf_get_lines = original_get_lines
		_G.vim.api.nvim_buf_set_extmark = original_set_extmark
	end)

	it("covers job_submit invalid inputs", function()
		local backend_command = {
			capture = function()
				return nil, "err"
			end,
		}
		package.loaded["tungsten.domains.plotting.workflow.backend_command"] = backend_command
		local job_manager = mock_utils.mock_module("tungsten.domains.plotting.job_manager", { submit = function() end })

		local notify_error = spy.new(function() end)
		local submit = require("tungsten.util.plotting.job_submit").submit

		submit(nil, notify_error, "fallback")
		submit({}, notify_error, "fallback")

		assert.spy(notify_error).was_called()
		assert.spy(job_manager.submit).was_not_called()
	end)

	it("formats AST structures", function()
		local ast_format = require("tungsten.util.ast_format")
		local formatted = ast_format.format({ type = "root", 1, child = { type = "leaf" } })
		assert.matches("root", formatted)
		assert.matches("child", formatted)
	end)
end)
