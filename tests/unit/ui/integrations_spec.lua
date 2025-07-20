local mock_utils = require("tests.helpers.mock_utils")
local vim_test_env = require("tests.helpers.vim_test_env")
local spy = require("luassert.spy")
local match = require("luassert.match")

local modules_to_reset = {
	"tungsten",
	"tungsten.config",
	"tungsten.core.commands",
	"tungsten.core.engine",
	"tungsten.core",
	"tungsten.ui.which_key",
	"tungsten.ui.commands",
	"tungsten.ui.status_window",
	"tungsten.ui",
	"which-key",
	"telescope",
	"telescope.pickers",
	"telescope.finders",
	"telescope.sorters",
	"telescope.actions",
	"telescope.actions.state",
}

local function reset_all()
	mock_utils.reset_modules(modules_to_reset)
end

before_each(function()
	reset_all()
end)

after_each(function()
	reset_all()
	vim.notify = vim.notify
	vim_test_env.cleanup()
end)

describe("Optional integrations", function()
	describe("Which-Key integration", function()
		it("loads without error when which-key is absent", function()
			package.loaded["which-key"] = nil
			local ok = pcall(require, "tungsten.ui.which_key")
			assert.is_true(ok)
		end)

		it("registers mappings when which-key is present", function()
			local wk_mock = mock_utils.create_empty_mock_module("which-key", { "add" })
			mock_utils.reset_modules({ "tungsten.ui.which_key" })
			local wk_module = require("tungsten.ui.which_key")
			assert.spy(wk_mock.add).was.called(1)
			assert.spy(wk_mock.add).was.called_with(wk_module.mappings)
		end)
	end)

	describe("Telescope integration", function()
		it("warns when telescope is missing", function()
			package.loaded["telescope"] = nil
			local notify_spy = spy.new(function() end)
			vim.notify = notify_spy
			local orig_schedule = vim.schedule
			vim.schedule = function(cb)
				cb()
			end

			require("tungsten").setup()

			local ok, err = pcall(vim.cmd, "TungstenPalette")
			assert.is_true(ok, err)
			assert.spy(notify_spy).was.called(1)
			vim.schedule = orig_schedule
		end)
	end)

	describe("Status window", function()
		it("creates a window displaying job details", function()
			local bufnr = vim_test_env.setup_buffer({ "" })
			local api = vim.api
			local orig_create_buf = api.nvim_create_buf
			local orig_set_lines = api.nvim_buf_set_lines
			local orig_open_win = api.nvim_open_win
			local orig_set_option = api.nvim_buf_set_option

			local create_buf_spy = spy.new(function()
				return 42
			end)
			local set_lines_spy = spy.new(function() end)
			local open_win_spy = spy.new(function()
				return 10
			end)
			local set_option_spy = spy.new(function() end)

			api.nvim_create_buf = create_buf_spy
			api.nvim_buf_set_lines = set_lines_spy
			api.nvim_open_win = open_win_spy
			api.nvim_buf_set_option = set_option_spy

			mock_utils.mock_module("tungsten.core.engine", {
				get_active_jobs_summary = function()
					return "line1\nline2"
				end,
			})

			require("tungsten").setup()

			vim.cmd("TungstenStatus")

			assert.spy(create_buf_spy).was.called(1)
			assert.spy(set_lines_spy).was.called_with(42, 0, -1, false, { "line1", "line2" })
			assert.spy(open_win_spy).was.called_with(42, true, match.is_table())

			api.nvim_create_buf = orig_create_buf
			api.nvim_buf_set_lines = orig_set_lines
			api.nvim_open_win = orig_open_win
			api.nvim_buf_set_option = orig_set_option
			vim_test_env.cleanup({ bufnr, 42 })
		end)
	end)

	it("computes width based on display width", function()
		local bufnr = vim_test_env.setup_buffer({ "" })
		local api = vim.api
		local orig_create_buf = api.nvim_create_buf
		local orig_set_lines = api.nvim_buf_set_lines
		local orig_open_win = api.nvim_open_win
		local orig_set_option = api.nvim_buf_set_option

		local create_buf_spy = spy.new(function()
			return 42
		end)
		local set_lines_spy = spy.new(function() end)
		local open_win_spy = spy.new(function()
			return 10
		end)
		local set_option_spy = spy.new(function() end)

		api.nvim_create_buf = create_buf_spy
		api.nvim_buf_set_lines = set_lines_spy
		api.nvim_open_win = open_win_spy
		api.nvim_buf_set_option = set_option_spy

		local summary = "αβγδ\nxy"
		mock_utils.mock_module("tungsten.core.engine", {
			get_active_jobs_summary = function()
				return summary
			end,
		})

		require("tungsten").setup()

		vim.cmd("TungstenStatus")

		local opts = open_win_spy.calls[1].vals[3]
		local expected = math.max(vim.fn.strdisplaywidth("αβγδ"), vim.fn.strdisplaywidth("xy"), 20)
		assert.are.equal(expected, opts.width)

		api.nvim_create_buf = orig_create_buf
		api.nvim_buf_set_lines = orig_set_lines
		api.nvim_open_win = orig_open_win
		api.nvim_buf_set_option = orig_set_option
		vim_test_env.cleanup({ bufnr, 42 })
	end)
end)
