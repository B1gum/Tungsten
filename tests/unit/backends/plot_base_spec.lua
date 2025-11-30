local mock_utils = require("tests.helpers.mock_utils")

describe("backends.plot_base", function()
	local plot_base

	before_each(function()
		mock_utils.reset_modules({ "tungsten.backends.plot_base" })
		plot_base = require("tungsten.backends.plot_base")
	end)

	it("normalizes output paths by appending a default extension", function()
		local opts = { out_path = "plots/output", format = "pdf" }
		plot_base.normalize_out_path(opts)
		assert.equals("plots/output.pdf", opts.out_path)

		local untouched = { out_path = "plots/image.png", format = "svg" }
		plot_base.normalize_out_path(untouched)
		assert.equals("plots/image.png", untouched.out_path)
	end)

	it("returns an error when out_path is missing", function()
		local opts, err = plot_base.prepare_opts(nil, function() end)
		assert.is_nil(opts)
		assert.same({ code = require("tungsten.util.error_handler").E_BAD_OPTS, message = "Missing out_path" }, err)

		local valid, no_err = plot_base.prepare_opts({ out_path = "plot" }, function() end)
		assert.is_table(valid)
		assert.is_nil(no_err)
		assert.equals("plot.png", valid.out_path)
	end)

	it("requires a callback when preparing opts", function()
		assert.has_error(function()
			plot_base.prepare_opts({ out_path = "file" })
		end)
	end)
end)
