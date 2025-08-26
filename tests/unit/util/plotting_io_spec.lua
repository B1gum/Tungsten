-- Unit tests for the plotting I/O and file management module.

local spy = require("luassert.spy")
local mock = require("luassert.mock")
local match = require("luassert.match")
local lfs = require("lfs")

describe("Plotting I/O and File Management", function()
	local plotting_io
	local temp_dir
	local original_os_rename
	local original_io_open

	before_each(function()
		temp_dir = vim.loop.fs_mkdtemp("tungsten_test_XXXXXX")
		lfs.mkdir(temp_dir .. "/project")
		lfs.mkdir(temp_dir .. "/project/sub")
		lfs.mkdir(temp_dir .. "/images")

		mock.revert_all()
		package.loaded["tungsten.domains.plotting.io"] = nil

		spy.on(vim.api, "nvim_buf_get_name", function()
			return temp_dir .. "/project/sub/document.tex"
		end)

		original_os_rename = os.rename
		original_io_open = io.open

		plotting_io = require("tungsten.domains.plotting.io")
	end)

	after_each(function()
		spy.restore_all()
		mock.revert_all()
		os.rename = original_os_rename
		io.open = original_io_open
		if temp_dir and lfs.attributes(temp_dir) then
			os.execute("rm -rf " .. temp_dir)
		end
	end)

	describe("TeX Root Detection", function()
		it("should detect the TeX root via a magic comment", function()
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

		it("should detect the TeX root by searching for \\documentclass in parent directories", function()
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

		it("should throw E_TEX_ROOT_NOT_FOUND if no root is detected", function()
			local sub_tex_path = temp_dir .. "/project/sub/document.tex"
			io.open(sub_tex_path, "w"):close()

			local root, err = plotting_io.find_tex_root(sub_tex_path)
			assert.is_nil(root)
			assert.are.equal("E_TEX_ROOT_NOT_FOUND", err.code)
		end)

		it("should prioritize the magic comment over a \\documentclass in the same file", function()
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
		it("should save images in 'tungsten_plots/' alongside the TeX root by default", function()
			local main_tex_path = temp_dir .. "/project/main.tex"
			io.open(main_tex_path, "w"):write("\\documentclass{article}"):close()

			local out_dir, err = plotting_io.get_output_directory(main_tex_path)
			assert.is_nil(err)
			assert.are.equal(temp_dir .. "/project/tungsten_plots", out_dir)
		end)

		it("should use the first \\graphicspath directory if available", function()
			local main_tex_path = temp_dir .. "/project/main.tex"
			local main_file = io.open(main_tex_path, "w")
			main_file:write("\\documentclass{article}\n\\graphicspath{{../images/}}")
			main_file:close()

			local out_dir, err = plotting_io.get_output_directory(main_tex_path)
			assert.is_nil(err)
			assert.are.equal(temp_dir .. "/images/tungsten_plots", out_dir)
		end)

		it("should create the output directory if it does not exist", function()
			local main_tex_path = temp_dir .. "/project/main.tex"
			io.open(main_tex_path, "w"):write("\\documentclass{article}"):close()
			local expected_dir = temp_dir .. "/project/tungsten_plots"
			assert.is_nil(lfs.attributes(expected_dir))

			plotting_io.ensure_output_path_exists(main_tex_path)

			assert.are.equal("directory", lfs.attributes(expected_dir, "mode"))
		end)
	end)

	describe("Filename Generation", function()
		it("should support sequential filename mode", function()
			local opts = { filename_mode = "sequential" }
			assert.are.equal("plot_001", plotting_io.generate_filename(opts, {}))
			assert.are.equal("plot_002", plotting_io.generate_filename(opts, {}))
		end)

		it("should support timestamp filename mode", function()
			mock(os, "date", spy.new(function(format)
				return "2025-08-26_12-30-00"
			end))

			local opts = { filename_mode = "timestamp" }
			local filename = plotting_io.generate_filename(opts, {})
			assert.are.equal("plot_2025-08-26_12-30-00", filename)
		end)

		it("should generate a correct SHA-256 hash for filenames", function()
			local opts = {
				filename_mode = "hash",
				backend = "python",
				format = "pdf",
				dim = 2,
				form = "explicit",
			}
			local plot_data = { ast = { type = "variable", name = "x" } }
			local filename1 = plotting_io.generate_filename(opts, plot_data)

			assert.is_true(string.match(filename1, "^plot_[a-f0-9]{12}$") ~= nil)

			local plot_data2 = { ast = { type = "variable", name = "y" } }
			local filename2 = plotting_io.generate_filename(opts, plot_data2)
			assert.are_not.equal(filename1, filename2)

			local filename3 = plotting_io.generate_filename(opts, plot_data)
			assert.are.equal(filename1, filename3)
		end)

		it("should reuse an existing image if a plot yields the same hash", function()
			local plot_dir = temp_dir .. "/project/tungsten_plots"
			lfs.mkdir(plot_dir)
			local plot_hash = "123456789abc"
			local existing_file_path = plot_dir .. "/plot_" .. plot_hash .. ".pdf"
			io.open(existing_file_path, "w"):close()

			mock(plotting_io, "_calculate_hash", spy.new(function()
				return plot_hash
			end))

			local opts = { filename_mode = "hash", format = "pdf" }
			local plot_data = { ast = { type = "variable", name = "x" } }
			local path, reused = plotting_io.get_final_path(plot_dir, opts, plot_data)

			assert.is_true(reused)
			assert.are.equal(existing_file_path, path)
		end)
	end)

	describe("File System Operations", function()
		it("should write image files atomically via rename", function()
			local temp_file_mock = { write = spy.new(function() end), close = spy.new(function() end) }
			local io_open_spy = spy.new(function(path, mode)
				if string.find(path, ".tmp") then
					return temp_file_mock
				end
				return original_io_open(path, mode)
			end)
			local os_rename_spy = spy.new(function(old, new)
				return true
			end)
			io.open = io_open_spy
			os.rename = os_rename_spy

			local final_path = temp_dir .. "/project/tungsten_plots/plot_final.png"
			plotting_io.write_atomically(final_path, "dummy_image_data")

			assert.spy(io_open_spy).was.called_with(match.string.endswith(".tmp"), "wb")
			assert.spy(temp_file_mock.write).was.called_with("dummy_image_data")
			assert.spy(temp_file_mock.close).was.called(1)
			assert.spy(os_rename_spy).was.called_with(match.string.endswith(".tmp"), final_path)
		end)

		it("should clean up the temporary file if rename fails", function()
			local io_open_spy = spy.new(function(path, mode)
				if string.find(path, ".tmp") then
					return { write = function() end, close = function() end }
				end
				return original_io_open(path, mode)
			end)
			local os_rename_spy = spy.new(function()
				return nil, "permission denied"
			end)
			local os_remove_spy = spy.new(function() end)
			io.open = io_open_spy
			os.rename = os_rename_spy
			os.remove = os_remove_spy

			local final_path = temp_dir .. "/project/tungsten_plots/plot_final.png"
			assert.has_error(function()
				plotting_io.write_atomically(final_path, "dummy_image_data")
			end, "Failed to rename temporary plot file: permission denied")
			assert.spy(os_rename_spy).was.called(1)
			assert.spy(os_remove_spy).was.called_with(match.string.endswith(".tmp"))
		end)
	end)
end)
