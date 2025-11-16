local stub = require("luassert.stub")
local async = require("tungsten.util.async")
local lfs = require("lfs")
local plot_backend = require("tungsten.backends.python.plot")
local executor = require("tungsten.backends.python.executor")
local config = require("tungsten.config")

describe("python polar plotting", function()
	local ast_stub

	before_each(function()
		ast_stub = stub(executor, "ast_to_code", function(ast)
			if type(ast) == "table" and ast.__code then
				return ast.__code
			end
			return "expr"
		end)
	end)

	after_each(function()
		if ast_stub then
			ast_stub:revert()
		end
	end)

	it("builds theta samples for polar plots", function()
		local opts = {
			dim = 2,
			form = "polar",
			theta_range = { 0, "2*np.pi" },
			samples = 180,
			series = {
				{
					kind = "function",
					ast = { r = { __code = "theta + 1" } },
					independent_vars = { "theta" },
				},
			},
		}

		local code, _, err = plot_backend.build_plot_code(opts)
		assert.is_nil(err)
		assert.is_truthy(code:find("theta_vals = np.linspace(0, 2*np.pi, 180)", 1, true))
		assert.is_truthy(code:find("ax.plot(theta_vals, f1(theta_vals))", 1, true))
	end)

	it("uses a polar axis when building scripts", function()
		local opts = {
			dim = 2,
			form = "polar",
			theta_range = { 0, "2*np.pi" },
			samples = 90,
			out_path = "polar.png",
			series = {
				{
					kind = "function",
					ast = { r = { __code = "theta" } },
					independent_vars = { "theta" },
				},
			},
		}

		local script, err = plot_backend.build_python_script(opts)
		assert.is_nil(err)
		assert.is_truthy(script:find("projection='polar'", 1, true))
	end)
	describe("python rcParams configuration", function()
		local ast_stub
		local original_plotting

		local function build_base_opts(overrides)
			local opts = {
				dim = 2,
				form = "explicit",
				xrange = { -1, 1 },
				samples = 50,
				out_path = "out.png",
				series = {
					{
						kind = "function",
						ast = { __code = "x" },
						independent_vars = { "x" },
					},
				},
			}
			for k, v in pairs(overrides or {}) do
				opts[k] = v
			end
			return opts
		end

		before_each(function()
			ast_stub = stub(executor, "ast_to_code", function(ast)
				if type(ast) == "table" and ast.__code then
					return ast.__code
				end
				return "expr"
			end)
			original_plotting = {}
			for k, v in pairs(config.plotting or {}) do
				original_plotting[k] = v
			end
		end)

		after_each(function()
			if ast_stub then
				ast_stub:revert()
			end
			if original_plotting then
				for k, v in pairs(original_plotting) do
					config.plotting[k] = v
				end
			end
		end)

		it("writes rcParams from explicit opts", function()
			local opts = build_base_opts({
				usetex = false,
				latex_preamble = "\\usepackage{siunitx}",
				latex_engine = "xelatex",
			})

			local script, err = plot_backend.build_python_script(opts)
			assert.is_nil(err)
			assert.is_truthy(script:find("matplotlib.rcParams['text.usetex'] = False", 1, true))
			assert.is_truthy(script:find("matplotlib.rcParams['text.latex.preamble'] = \"\\\\usepackage{siunitx}\"", 1, true))
			assert.is_truthy(script:find("matplotlib.rcParams['pgf.texsystem'] = \"xelatex\"", 1, true))
			assert.is_nil(script:find("TEXINPUTS", 1, true))
		end)

		it("falls back to config defaults and configures pdflatex", function()
			config.plotting.usetex = true
			config.plotting.latex_preamble = "\\usepackage{amsmath}"
			config.plotting.latex_engine = "pdflatex"

			local script, err = plot_backend.build_python_script(build_base_opts())
			assert.is_nil(err)
			assert.is_truthy(script:find("matplotlib.rcParams['text.usetex'] = True", 1, true))
			assert.is_truthy(script:find("matplotlib.rcParams['text.latex.preamble'] = \"\\\\usepackage{amsmath}\"", 1, true))
			assert.is_truthy(script:find("matplotlib.rcParams['pgf.texsystem'] = \"pdflatex\"", 1, true))
			assert.is_truthy(script:find("texinputs = os.environ.get('TEXINPUTS', '')", 1, true))
			assert.is_truthy(script:find("os.environ['TEXINPUTS'] = texinputs", 1, true))
		end)
	end)

	describe("python plot_async working directory", function()
		local ast_stub
		local run_job_stub
		local temp_dir

		local function create_basic_opts(overrides)
			local opts = {
				dim = 2,
				form = "explicit",
				out_path = temp_dir .. "/project/tungsten_plots/plot.png",
				series = {
					{
						kind = "function",
						ast = { __code = "x" },
						independent_vars = { "x" },
					},
				},
			}

			if overrides then
				for k, v in pairs(overrides) do
					opts[k] = v
				end
			end

			return opts
		end

		before_each(function()
			temp_dir = vim.loop.fs_mkdtemp("tungsten_plot_async_XXXXXX")
			lfs.mkdir(temp_dir .. "/project")
			lfs.mkdir(temp_dir .. "/project/tungsten_plots")

			ast_stub = stub(executor, "ast_to_code", function(ast)
				if type(ast) == "table" and ast.__code then
					return ast.__code
				end
				return "expr"
			end)

			run_job_stub = stub(async, "run_job", function(_cmd, opts)
				if opts.on_exit then
					opts.on_exit(0, "ok", "")
				end
				return {}
			end)
		end)

		after_each(function()
			if run_job_stub then
				run_job_stub:revert()
			end
			if ast_stub then
				ast_stub:revert()
			end
			if temp_dir and lfs.attributes(temp_dir) then
				os.execute("rm -rf " .. temp_dir)
			end
		end)

		it("runs python from the TeX root directory so relative assets resolve", function()
			local tex_root = temp_dir .. "/project/main.tex"
			io.open(tex_root, "w"):close()

			local opts = create_basic_opts({ tex_root = tex_root })
			plot_backend.plot_async(opts, function() end)

			assert.spy(run_job_stub).was.called(1)
			local job_opts = run_job_stub.calls[1].vals[2]
			assert.are.equal(temp_dir .. "/project", job_opts.cwd)
		end)

		it("falls back to the output directory when no TeX root exists", function()
			local opts = create_basic_opts({ tex_root = nil })
			plot_backend.plot_async(opts, function() end)

			assert.spy(run_job_stub).was.called(1)
			local job_opts = run_job_stub.calls[1].vals[2]
			assert.are.equal(temp_dir .. "/project/tungsten_plots", job_opts.cwd)
		end)
	end)
end)
