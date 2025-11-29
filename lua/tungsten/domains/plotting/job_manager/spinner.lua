local M = {}

local spinner_ns = vim.api.nvim_create_namespace("tungsten_plot_spinner")
local spinner_frames = {
	"⠋",
	"⠙",
	"⠹",
	"⠸",
	"⠼",
	"⠴",
	"⠦",
	"⠧",
	"⠇",
	"⠏",
}
local spinner_interval = 80

function M.start_spinner(bufnr, row, col)
	local frame_index = 1
	local extmark_id = vim.api.nvim_buf_set_extmark(bufnr, spinner_ns, row, col, {
		virt_text = { { spinner_frames[frame_index] } },
		virt_text_pos = "overlay",
	})

	local timer = vim.loop.new_timer()
	if timer then
		local function update_spinner()
			frame_index = frame_index % #spinner_frames + 1
			local next_frame = spinner_frames[frame_index]
			vim.schedule(function()
				pcall(vim.api.nvim_buf_set_extmark, bufnr, spinner_ns, row, col, {
					id = extmark_id,
					virt_text = { { next_frame } },
					virt_text_pos = "overlay",
				})
			end)
		end

		timer:start(spinner_interval, spinner_interval, update_spinner)
	end

	return extmark_id, timer, spinner_ns
end

return M
