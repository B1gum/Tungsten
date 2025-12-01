local mock_utils = require("tests.helpers.mock_utils")
local spy = require("luassert.spy")
local match = require("luassert.match")

local function reset_modules()
	mock_utils.reset_modules({
		"tungsten.ui.commands",
		"tungsten.ui.init",
		"tungsten.ui.mappings",
		"tungsten.ui.picker",
		"tungsten.ui.plotting",
		"tungsten.event_bus",
		"tungsten.util.logger",
		"tungsten.util.insert_result",
		"tungsten.backends.manager",
		"tungsten.core.parser",
		"tungsten.core.engine",
		"telescope",
		"telescope.pickers",
		"telescope.finders",
		"telescope.sorters",
		"telescope.actions",
		"telescope.actions.state",
	})
	package.preload["telescope"] = nil
	package.preload["telescope.pickers"] = nil
	package.preload["telescope.finders"] = nil
	package.preload["telescope.sorters"] = nil
	package.preload["telescope.actions"] = nil
	package.preload["telescope.actions.state"] = nil
end

describe("UI coverage", function()
	after_each(function()
		reset_modules()
	end)

	describe("commands", function()
		it("warns when telescope is missing", function()
			local warn_spy = spy.new(function() end)
			mock_utils.mock_module("tungsten.util.logger", { warn = warn_spy })

			local orig_schedule = vim.schedule
			vim.schedule = function(cb)
				cb()
			end

			package.preload["telescope"] = function()
				error("no telescope")
			end

			local created_cmd
			local orig_create_cmd = vim.api.nvim_create_user_command
			vim.api.nvim_create_user_command = function(_, cb)
				created_cmd = cb
			end

			require("tungsten.ui.commands")

			assert.is_function(created_cmd)
			created_cmd()

			assert.spy(warn_spy).was.called_with("Telescope not found. Install telescope.nvim for enhanced UI.")

			vim.api.nvim_create_user_command = orig_create_cmd
			vim.schedule = orig_schedule
		end)

		it("loads extension when first open returns false", function()
			local warn_spy = spy.new(function() end)
			mock_utils.mock_module("tungsten.util.logger", { warn = warn_spy })

			local load_extension_spy = spy.new(function() end)
			local call_count = 0
			local open_spy = spy.new(function()
				call_count = call_count + 1
				return call_count > 1
			end)

			mock_utils.mock_module("telescope", {
				extensions = { tungsten = { open = open_spy } },
				load_extension = load_extension_spy,
			})

			local created_cmd
			local orig_create_cmd = vim.api.nvim_create_user_command
			vim.api.nvim_create_user_command = function(_, cb)
				created_cmd = cb
			end

			require("tungsten.ui.commands")
			created_cmd()

			assert.spy(open_spy).was.called(2)
			assert.spy(load_extension_spy).was.called_with("tungsten")
			assert.spy(warn_spy).was_not.called()

			vim.api.nvim_create_user_command = orig_create_cmd
		end)

		it("warns when extension is missing an open function", function()
			local warn_spy = spy.new(function() end)
			mock_utils.mock_module("tungsten.util.logger", { warn = warn_spy })

			local telescope_mock = { extensions = { tungsten = {} } }
			telescope_mock.extensions.tungsten.open = function()
				telescope_mock.extensions.tungsten.open = nil
				return false
			end
			telescope_mock.load_extension = function(_)
				telescope_mock.extensions.tungsten = telescope_mock.extensions.tungsten or {}
			end
			package.loaded["telescope"] = telescope_mock

			local created_cmd
			local orig_create_cmd = vim.api.nvim_create_user_command
			vim.api.nvim_create_user_command = function(_, cb)
				created_cmd = cb
			end

			local orig_schedule = vim.schedule
			vim.schedule = function(cb)
				cb()
			end

			require("tungsten.ui.commands")
			created_cmd()

			assert.spy(warn_spy).was.called_with("Failed to load Tungsten telescope extension.")

			vim.schedule = orig_schedule

			vim.api.nvim_create_user_command = orig_create_cmd
		end)
	end)

	describe("init", function()
		it("warns when telescope pickers are missing", function()
			local warn_spy = spy.new(function() end)
			mock_utils.mock_module("tungsten.util.logger", { warn = warn_spy })
			mock_utils.mock_module("tungsten.ui.picker", {
				list = function()
					return {}
				end,
			})

			package.preload["telescope.pickers"] = function()
				error("pickers missing")
			end

			local orig_schedule = vim.schedule
			vim.schedule = function(cb)
				cb()
			end

			local ui_init = require("tungsten.ui.init")
			ui_init.open({})

			vim.schedule = orig_schedule

			assert.spy(warn_spy).was.called_with("Telescope not found. Install telescope.nvim for enhanced UI.")
		end)

		it("warns when no commands are registered", function()
			local warn_spy = spy.new(function() end)
			mock_utils.mock_module("tungsten.util.logger", { warn = warn_spy })
			mock_utils.mock_module("tungsten.ui.picker", {
				list = function()
					return {}
				end,
			})
			mock_utils.mock_module("telescope.pickers", { new = function() end })
			mock_utils.mock_module("telescope.finders", { new_table = function() end })
			mock_utils.mock_module("telescope.sorters", { get_fuzzy_file = function() end })

			local ui_init = require("tungsten.ui.init")
			ui_init.open({})

			assert.spy(warn_spy).was.called_with("Tungsten", "No Tungsten commands found.")
		end)

		it("invokes telescope picker with attached mappings", function()
			mock_utils.mock_module("tungsten.util.logger", { warn = function() end })

			local list_spy = spy.new(function()
				return {
					{ value = "TungstenStatus", display = "Status", ordinal = "Status" },
				}
			end)
			mock_utils.mock_module("tungsten.ui.picker", { list = list_spy })

			local new_spy = spy.new(function(_, opts)
				return {
					find = spy.new(function() end),
					opts = opts,
				}
			end)
			local finder_spy = spy.new(function(tbl)
				return tbl
			end)
			local sorter_spy = spy.new(function()
				return "sorter"
			end)

			mock_utils.mock_module("telescope.pickers", { new = new_spy })
			mock_utils.mock_module("telescope.finders", { new_table = finder_spy })
			mock_utils.mock_module("telescope.sorters", { get_fuzzy_file = sorter_spy })

			local attach_spy = spy.new(function()
				return true
			end)
			mock_utils.mock_module("tungsten.ui.mappings", { attach = attach_spy })

			local ui_init = require("tungsten.ui.init")
			ui_init.open({})

			assert.spy(list_spy).was.called(1)
			assert.spy(new_spy).was.called(1)
			local opts = new_spy.calls[1].vals[2]
			assert.are.equal(attach_spy, opts.attach_mappings)
			assert.spy(finder_spy).was.called_with(match.is_table())
			assert.spy(sorter_spy).was.called(1)
		end)

		it("registers telescope extension and handles result events", function()
			local registered
			mock_utils.mock_module("telescope", {
				register_extension = function(ext)
					registered = ext.exports.open
				end,
			})

			local insert_spy = spy.new(function() end)
			mock_utils.mock_module("tungsten.util.insert_result", { insert_result = insert_spy })

			require("tungsten.ui.init")

			assert.is_function(registered)
			registered({})

			local event_bus = require("tungsten.event_bus")
			event_bus.emit("result_ready", {
				result = "42",
				start_mark = { 1, 0 },
				end_mark = { 1, 0 },
				selection_text = "x",
				mode = "v",
			})

			assert.spy(insert_spy).was.called_with("42", nil, { 1, 0 }, { 1, 0 }, "x", "v")
		end)
	end)

	describe("mappings", function()
		it("returns false when telescope actions are unavailable", function()
			package.preload["telescope.actions"] = function()
				error("missing actions")
			end
			package.preload["telescope.actions.state"] = function()
				error("missing state")
			end

			local mappings = require("tungsten.ui.mappings")
			assert.is_false(mappings.attach(1, {}))
		end)

		it("runs selected command when entry is present", function()
			local close_spy = spy.new(function() end)
			local replacement
			local select_default = {
				replace = function(_, fn)
					replacement = fn
				end,
			}
			local actions_mock = { select_default = select_default, close = close_spy }
			local entry = { value = "echo hi" }
			local orig_cmd = vim.cmd
			vim.cmd = spy.new(function() end)
			mock_utils.mock_module("telescope.actions", actions_mock)
			mock_utils.mock_module("telescope.actions.state", {
				get_selected_entry = function()
					return entry
				end,
			})

			local mappings = require("tungsten.ui.mappings")
			local attached = mappings.attach(5, {})
			assert.is_true(attached)

			replacement()
			assert.spy(close_spy).was.called_with(5)
			assert.spy(vim.cmd).was.called_with("echo hi")
			-- ensure vim.cmd executed without error

			vim.cmd = orig_cmd
		end)

		it("warns when no entry is selected", function()
			local warn_spy = spy.new(function() end)
			mock_utils.mock_module("tungsten.util.logger", { warn = warn_spy })
			local replacement
			local select_default = {
				replace = function(_, fn)
					replacement = fn
				end,
			}
			mock_utils.mock_module("telescope.actions", { select_default = select_default, close = function() end })
			mock_utils.mock_module("telescope.actions.state", {
				get_selected_entry = function()
					return nil
				end,
			})

			local mappings = require("tungsten.ui.mappings")
			mappings.attach(2, {})
			replacement()

			assert.spy(warn_spy).was.called_with("No command selected")
		end)
	end)

	describe("picker", function()
		it("collects and sorts Tungsten commands", function()
			local orig_get_commands = vim.api.nvim_get_commands
			vim.api.nvim_get_commands = function()
				return {
					TungstenB = { description = "bbb" },
					Other = { description = "zzz" },
					TungstenA = { description = "aaa" },
				}
			end

			local picker = require("tungsten.ui.picker")
			local items = picker.list()

			assert.are.same({
				{ value = "TungstenA", display = "aaa", ordinal = "aaa" },
				{ value = "TungstenB", display = "bbb", ordinal = "bbb" },
			}, items)

			vim.api.nvim_get_commands = orig_get_commands
		end)
	end)

	describe("plotting helpers", function()
		local function get_upvalue(fn, name)
			local i = 1
			while true do
				local upname, value = debug.getupvalue(fn, i)
				if not upname then
					break
				end
				if upname == name then
					return value
				end
				i = i + 1
			end
		end

		it("covers numeric parsing edge cases", function()
			local plotting = require("tungsten.ui.plotting")
			local handle_symbols = plotting.handle_undefined_symbols
			local evaluate_definitions = get_upvalue(handle_symbols, "evaluate_definitions")
			local evaluate_definition = get_upvalue(evaluate_definitions, "evaluate_definition")
			local parse_numeric_result = get_upvalue(evaluate_definition, "parse_numeric_result")

			assert.is_function(parse_numeric_result)

			assert.are.equal(5, parse_numeric_result(5))
			assert.is_nil(parse_numeric_result({}))
			assert.is_nil(parse_numeric_result("   "))
			assert.are.same({ 1, 2, 3 }, parse_numeric_result("(1,2,3)"))
			assert.is_nil(parse_numeric_result("(1,,3)"))
			assert.is_nil(parse_numeric_result("(a,b,c)"))
			assert.are.equal(2000, parse_numeric_result("2\\times10^{3}"))
			assert.are.equal(100, parse_numeric_result("10^{2}"))
		end)

		it("validates definitions and dependencies", function()
			mock_utils.mock_module("tungsten.backends.manager", {
				current = function()
					return true
				end,
			})
			local parse_spy = spy.new(function(_, _)
				return { series = { { mock = true } } }
			end)
			mock_utils.mock_module("tungsten.core.parser", { parse = parse_spy })
			local eval_spy = spy.new(function(_, _, cb)
				cb(nil, "Unknown symbol b")
			end)
			mock_utils.mock_module("tungsten.core.engine", { evaluate_async = eval_spy })
			mock_utils.mock_module("tungsten.util.logger", { warn = function() end })

			local plotting = require("tungsten.ui.plotting")
			local handle_symbols = plotting.handle_undefined_symbols
			local evaluate_definitions = get_upvalue(handle_symbols, "evaluate_definitions")

			local failure_spy = spy.new(function() end)
			evaluate_definitions(
				{ a = { latex = "1" }, b = { latex = "2" }, __order = { "a", "b" } },
				function() end,
				failure_spy
			)

			assert.spy(failure_spy).was.called()
			local mt = getmetatable("")
			local _, message = mt.__index.table.unpack(failure_spy.calls[1].vals)
			assert.is_true(message:find("depends on 'b'", 1, true) ~= nil)

			local success_spy = spy.new(function() end)
			evaluate_definitions(nil, success_spy)
			assert.spy(success_spy).was.called()
		end)

		it("normalizes buffer lines and populates defaults", function()
			local plotting = require("tungsten.ui.plotting")
			local handle_symbols = plotting.handle_undefined_symbols
			local normalize_buffer_lines = get_upvalue(handle_symbols, "normalize_buffer_lines")
			local populate_symbol_buffer = get_upvalue(handle_symbols, "populate_symbol_buffer")

			local normalized = normalize_buffer_lines({ "Variables:", "a: 1", "b := 2", "c" })
			assert.are.equal("a:=1\nb := 2\nc:=", normalized)

			local lines = populate_symbol_buffer({ { name = "f", type = "function" } })
			assert.are.same({ "Functions:", "f:=" }, lines)
		end)

		it("warns once when math block ending is missing", function()
			local plotting = require("tungsten.ui.plotting")
			local warn_missing_math_block_end = get_upvalue(plotting.insert_snippet, "warn_missing_math_block_end")
				or get_upvalue(plotting.handle_output, "warn_missing_math_block_end")

			assert.is_function(warn_missing_math_block_end)

			local notify_spy = spy.new(function() end)
			local orig_notify = vim.notify
			local orig_notify_once = vim.notify_once
			vim.notify = notify_spy
			vim.notify_once = nil

			warn_missing_math_block_end()
			warn_missing_math_block_end()

			assert.spy(notify_spy).was.called(1)
			vim.notify = orig_notify
			vim.notify_once = orig_notify_once
		end)
	end)
end)
