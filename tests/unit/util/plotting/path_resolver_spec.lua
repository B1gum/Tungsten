local vim_test_env = require("tests.helpers.vim_test_env")
local error_handler = require("tungsten.util.error_handler")
local plotting_io = require("tungsten.domains.plotting.io")

local function with_overrides(overrides, cb)
	local originals = {}
	for key, value in pairs(overrides) do
		originals[key] = plotting_io[key]
		plotting_io[key] = value
	end

	cb()

	for key, value in pairs(originals) do
		plotting_io[key] = value
	end
end

describe("plotting_io.resolve_paths", function()
	it("resolves tex root and output directory for a buffer", function()
		local bufnr = vim_test_env.setup_buffer({ "content" })
		local named_path = "/tmp/example.tex"
		local original_get_name = vim.api.nvim_buf_get_name
		vim.api.nvim_buf_get_name = function(target_bufnr)
			assert.equals(bufnr, target_bufnr)
			return named_path
		end

		local captured_path, captured_root
		with_overrides({
			find_tex_root = function(buf_path)
				captured_path = buf_path
				return "/tmp/root.tex"
			end,
			get_output_directory = function(tex_root)
				captured_root = tex_root
				return "/tmp/out", nil, true
			end,
		}, function()
			local tex_root, output_dir, uses_graphicspath, err = plotting_io.resolve_paths(bufnr)

			assert.is_nil(err)
			assert.equals("/tmp/root.tex", tex_root)
			assert.equals("/tmp/out", output_dir)
			assert.is_true(uses_graphicspath)
			assert.equals(named_path, captured_path)
			assert.equals("/tmp/root.tex", captured_root)
		end)

		vim.api.nvim_buf_get_name = original_get_name
	end)

	it("returns a normalized tex root error when resolution fails", function()
		with_overrides({
			find_tex_root = function()
				return nil, "E_TEX_ROOT_NOT_FOUND"
			end,
			get_output_directory = function()
				return "/tmp/out", nil, false
			end,
		}, function()
			local tex_root, output_dir, uses_graphicspath, err = plotting_io.resolve_paths(0)

			assert.is_nil(tex_root)
			assert.is_nil(output_dir)
			assert.is_nil(uses_graphicspath)
			assert.same({ code = error_handler.E_TEX_ROOT_NOT_FOUND }, err)
		end)
	end)

	it("wraps output directory errors with E_BAD_OPTS", function()
		with_overrides({
			find_tex_root = function()
				return "/tmp/root.tex", nil
			end,
			get_output_directory = function()
				return nil, "failed to create dir", false
			end,
		}, function()
			local tex_root, output_dir, uses_graphicspath, err = plotting_io.resolve_paths(0)

			assert.is_nil(tex_root)
			assert.is_nil(output_dir)
			assert.is_nil(uses_graphicspath)
			assert.same({ code = error_handler.E_BAD_OPTS, message = "failed to create dir" }, err)
		end)
	end)
end)
