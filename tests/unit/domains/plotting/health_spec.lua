local mock_utils = require("tests.helpers.mock_utils")

describe("Plotting dependency health", function()
	local health
	local original_executable
	local original_jobstart
	local original_jobwait

	before_each(function()
		mock_utils.reset_modules({ "tungsten.domains.plotting.health" })
		health = require("tungsten.domains.plotting.health")
		original_executable = vim.fn.executable
		original_jobstart = vim.fn.jobstart
		original_jobwait = vim.fn.jobwait
	end)

	after_each(function()
		vim.fn.executable = original_executable
		vim.fn.jobstart = original_jobstart
		vim.fn.jobwait = original_jobwait
	end)

	it("reports all dependencies available", function()
		vim.fn.executable = function(bin)
			if bin == "wolframscript" or bin == "python3" then
				return 1
			end
			return 0
		end
		vim.fn.jobstart = function(cmd, opts)
			if cmd[1] == "wolframscript" then
				if opts.on_stdout then
					opts.on_stdout(nil, { "13.1.0", "" })
				end
				if opts.on_exit then
					opts.on_exit(nil, 0)
				end
				return 1
			elseif cmd[1] == "python3" then
				if opts.on_stdout then
					opts.on_stdout(nil, {
						'{"python":"3.11.0","numpy":"1.23.5","sympy":"1.12","matplotlib":"3.6.3"}',
						"",
					})
				end
				if opts.on_exit then
					opts.on_exit(nil, 0)
				end
				return 2
			end
			return -1
		end
		vim.fn.jobwait = function(_)
			return { 0 }
		end

		local report = health.check_dependencies()
		assert.is_true(report.wolframscript.ok)
		assert.is_true(report.python.ok)
		assert.is_true(report.numpy.ok)
		assert.is_true(report.sympy.ok)
		assert.is_true(report.matplotlib.ok)
	end)

	it("handles missing python", function()
		vim.fn.executable = function(bin)
			if bin == "wolframscript" then
				return 0
			end
			return 0
		end
		vim.fn.jobstart = function()
			return -1
		end
		vim.fn.jobwait = function()
			return { -1 }
		end

		local report = health.check_dependencies()
		assert.is_false(report.wolframscript.ok)
		assert.is_false(report.python.ok)
		assert.is_false(report.numpy.ok)
		assert.is_false(report.sympy.ok)
		assert.is_false(report.matplotlib.ok)
	end)

	describe("version comparison", function()
		local compare

		before_each(function()
			mock_utils.reset_modules({ "tungsten.domains.plotting.health" })
			compare = require("tungsten.domains.plotting.health").version_at_least
		end)

		it("handles rc prereleases", function()
			assert.is_true(compare("1.2", "1.2rc1"))
			assert.is_false(compare("1.2rc1", "1.2"))
		end)

		it("handles dev prereleases", function()
			assert.is_true(compare("1.2.0", "1.2.0-dev"))
			assert.is_false(compare("1.2.0-dev", "1.2.0"))
		end)

		it("handles normal releases", function()
			assert.is_true(compare("1.2.1", "1.2.0"))
			assert.is_false(compare("1.2.0", "1.2.1"))
		end)
	end)
end)
