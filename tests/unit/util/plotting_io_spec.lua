-- Unit tests for the plotting I/O module covering TeX root and output directory logic.

describe("Plotting I/O and File Management", function()
	local plotting_io
	local temp_dir
	local original_get_name
	local uv = vim.uv or vim.loop

	before_each(function()
		temp_dir = uv.fs_mkdtemp("tungsten_test_XXXXXX")

		vim.fn.mkdir(temp_dir .. "/project", "p")
		vim.fn.mkdir(temp_dir .. "/project/sub", "p")
		vim.fn.mkdir(temp_dir .. "/images", "p")

		package.loaded["tungsten.domains.plotting.io"] = nil

		original_get_name = vim.api.nvim_buf_get_name
		vim.api.nvim_buf_get_name = function()
			return temp_dir .. "/project/sub/document.tex"
		end

		plotting_io = require("tungsten.domains.plotting.io")
	end)

	after_each(function()
		vim.api.nvim_buf_get_name = original_get_name
		if temp_dir and uv.fs_stat(temp_dir) then
			vim.fn.delete(temp_dir, "rf")
		end
	end)

	describe("TeX Root Detection", function()
		it("detects the TeX root via a magic comment", function()
			local main_tex_path = temp_dir .. "/project/main.tex"
			local sub_tex_path = temp_dir .. "/project/sub/document.tex"
			io.open(main_tex_path, "w"):close()
			local sub_file = io.open(sub_tex_path, "w")
			sub_file:write("%!TEX root = ../main.tex\n\\documentclass{article}")
			sub_file:close()

			local root, err = plotting_io.find_tex_root(sub_tex_path)
			assert.is_nil(err)
			assert.are.equal(main_tex_path, root)
		end)

		it("detects the TeX root by searching for \\documentclass in parent directories", function()
			local main_tex_path = temp_dir .. "/project/main.tex"
			local sub_tex_path = temp_dir .. "/project/sub/document.tex"
			local main_file = io.open(main_tex_path, "w")
			main_file:write("\\documentclass{article}\n\\begin{document}\nHello\n\\end{document}")
			main_file:close()
			io.open(sub_tex_path, "w"):close()

			local root, err = plotting_io.find_tex_root(sub_tex_path)
			assert.is_nil(err)
			assert.are.equal(main_tex_path, root)
		end)

		it("returns E_TEX_ROOT_NOT_FOUND if no root is detected", function()
			local sub_tex_path = temp_dir .. "/project/sub/document.tex"
			io.open(sub_tex_path, "w"):close()

			local root, err = plotting_io.find_tex_root(sub_tex_path)
			assert.is_nil(root)
			assert.are.equal("E_TEX_ROOT_NOT_FOUND", err.code)
			assert.is_truthy(err.message:find("%%!TEX root"))
		end)

		it("prioritizes the magic comment over a \\documentclass in the same file", function()
			local real_root_path = temp_dir .. "/project/real_root.tex"
			local misleading_doc_path = temp_dir .. "/project/sub/document.tex"
			io.open(real_root_path, "w"):close()
			local misleading_file = io.open(misleading_doc_path, "w")
			misleading_file:write("%!TEX root = ../real_root.tex\n\\documentclass{article}")
			misleading_file:close()

			local root, err = plotting_io.find_tex_root(misleading_doc_path)
			assert.is_nil(err)
			assert.are.equal(real_root_path, root)
		end)
	end)

	describe("Output Directory Management", function()
		it("saves images in 'tungsten_plots/' alongside the TeX root by default", function()
			local main_tex_path = temp_dir .. "/project/main.tex"
			local f = io.open(main_tex_path, "w")
			f:write("\\documentclass{article}")
			f:close()

			local out_dir, err, used_graphicspath = plotting_io.get_output_directory(main_tex_path)
			assert.is_nil(err)
			assert.are.equal(temp_dir .. "/project/tungsten_plots", out_dir)
			assert.is_false(used_graphicspath)
		end)

		it("uses the first \\graphicspath directory if available", function()
			local main_tex_path = temp_dir .. "/project/main.tex"
			local main_file = io.open(main_tex_path, "w")
			main_file:write("\\documentclass{article}\n\\graphicspath{{../images/}}")
			main_file:close()
			local out_dir, err, used_graphicspath = plotting_io.get_output_directory(main_tex_path)
			assert.is_nil(err)
			assert.are.equal(temp_dir .. "/images/tungsten_plots", out_dir)
			assert.is_true(used_graphicspath)
		end)

		it("handles multi-entry \\graphicspath declarations", function()
			local main_tex_path = temp_dir .. "/project/main.tex"
			local main_file = io.open(main_tex_path, "w")
			main_file:write("\\documentclass{article}\n\\graphicspath{{../images/}{../other/}}")
			main_file:close()

			local out_dir, err, used_graphicspath = plotting_io.get_output_directory(main_tex_path)
			assert.is_nil(err)
			assert.are.equal(temp_dir .. "/images/tungsten_plots", out_dir)
			assert.is_nil(out_dir:match("[{]"))
			assert.is_nil(out_dir:match("[}]"))
			assert.is_true(used_graphicspath)
		end)

		it("creates the output directory if it does not exist", function()
			local main_tex_path = temp_dir .. "/project/main.tex"
			local f = io.open(main_tex_path, "w")
			f:write("\\documentclass{article}")
			f:close()
			local expected_dir = temp_dir .. "/project/tungsten_plots"

			assert.is_nil(uv.fs_stat(expected_dir))

			local out_dir, err, used_graphicspath = plotting_io.get_output_directory(main_tex_path)
			assert.is_nil(err)
			assert.are.equal(expected_dir, out_dir)

			local stat = uv.fs_stat(expected_dir)
			assert.is_not_nil(stat)
			assert.are.equal("directory", stat.type)
			assert.is_false(used_graphicspath)
		end)
	end)

	describe("Filename Generation", function()
		it("defaults to sequential filenames", function()
			local n1 = plotting_io.generate_filename({}, {})
			local n2 = plotting_io.generate_filename({}, {})
			assert.are.equal("plot_001", n1)
			assert.are.equal("plot_002", n2)
		end)

		it("generates sequential filenames with zero padding", function()
			local opts = { filename_mode = "sequential" }
			local n1 = plotting_io.generate_filename(opts, {})
			local n2 = plotting_io.generate_filename(opts, {})
			assert.are.equal("plot_001", n1)
			assert.are.equal("plot_002", n2)
		end)

		it("generates timestamp-based filenames", function()
			local opts = { filename_mode = "timestamp" }
			local name = plotting_io.generate_filename(opts, {})
			assert.is_truthy(name:match("^plot_%d%d%d%d%-%d%d%-%d%d_%d%d%-%d%d%-%d%d$"))
		end)
	end)

	describe("Final Path Assembly and Atomic Writes", function()
		it("detects when an output would overwrite an existing file", function()
			local out_dir = temp_dir .. "/project/tungsten_plots"
			vim.fn.mkdir(out_dir, "p")

			local opts = { filename_mode = "sequential", format = "pdf" }
			local path1, reused1 = plotting_io.get_final_path(out_dir, opts, {})
			assert.is_false(reused1)

			local f = io.open(path1, "w")
			f:write("dummy")
			f:close()

			package.loaded["tungsten.domains.plotting.io"] = nil
			plotting_io = require("tungsten.domains.plotting.io")

			local path2, reused2 = plotting_io.get_final_path(out_dir, opts, {})
			assert.is_true(reused2)
			assert.are.equal(path1, path2)
		end)

		it("performs atomic file writes", function()
			local out_dir = temp_dir .. "/project/tungsten_plots"
			vim.fn.mkdir(out_dir, "p")
			local final_path = out_dir .. "/atomic_test.dat"

			local ok, err = plotting_io.write_atomically(final_path, "hello")
			assert.is_true(ok)
			assert.is_nil(err)

			local f = io.open(final_path, "rb")
			local content = f:read("*a")
			f:close()
			assert.are.equal("hello", content)

			assert.is_nil(uv.fs_stat(final_path .. ".tmp"))
		end)
	end)
end)
