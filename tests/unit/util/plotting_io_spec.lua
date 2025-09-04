-- Unit tests for the plotting I/O module covering TeX root and output directory logic.

local lfs = require("lfs")

describe("Plotting I/O and File Management", function()
	local plotting_io
	local temp_dir
	local original_get_name

	before_each(function()
		temp_dir = vim.loop.fs_mkdtemp("tungsten_test_XXXXXX")
		lfs.mkdir(temp_dir .. "/project")
		lfs.mkdir(temp_dir .. "/project/sub")
		lfs.mkdir(temp_dir .. "/images")

		package.loaded["tungsten.domains.plotting.io"] = nil

		original_get_name = vim.api.nvim_buf_get_name
		vim.api.nvim_buf_get_name = function()
			return temp_dir .. "/project/sub/document.tex"
		end

		plotting_io = require("tungsten.domains.plotting.io")
	end)

	after_each(function()
		vim.api.nvim_buf_get_name = original_get_name
		if temp_dir and lfs.attributes(temp_dir) then
			os.execute("rm -rf " .. temp_dir)
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

			local out_dir, err = plotting_io.get_output_directory(main_tex_path)
			assert.is_nil(err)
			assert.are.equal(temp_dir .. "/project/tungsten_plots", out_dir)
		end)

		it("uses the first \\graphicspath directory if available", function()
			local main_tex_path = temp_dir .. "/project/main.tex"
			local main_file = io.open(main_tex_path, "w")
			main_file:write("\\documentclass{article}\n\\graphicspath{{../images/}}")
			main_file:close()

			local out_dir, err = plotting_io.get_output_directory(main_tex_path)
			assert.is_nil(err)
			assert.are.equal(temp_dir .. "/images/tungsten_plots", out_dir)
		end)

		it("creates the output directory if it does not exist", function()
			local main_tex_path = temp_dir .. "/project/main.tex"
			local f = io.open(main_tex_path, "w")
			f:write("\\documentclass{article}")
			f:close()
			local expected_dir = temp_dir .. "/project/tungsten_plots"
			assert.is_nil(lfs.attributes(expected_dir))

			local out_dir, err = plotting_io.get_output_directory(main_tex_path)
			assert.is_nil(err)
			assert.are.equal(expected_dir, out_dir)
			assert.are.equal("directory", lfs.attributes(expected_dir, "mode"))
		end)
	end)
end)
