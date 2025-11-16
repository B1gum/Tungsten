local stub = require("luassert.stub")
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
end)
