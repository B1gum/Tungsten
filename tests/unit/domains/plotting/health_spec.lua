local mock_utils = require("tests.helpers.mock_utils")
local wait_for = require("tests.helpers.wait").wait_for

describe("Plotting dependency health", function()
	local health
	local original_executable
	local original_system

	before_each(function()
		mock_utils.reset_modules({ "tungsten.domains.plotting.health" })
		health = require("tungsten.domains.plotting.health")
		original_executable = vim.fn.executable
		original_system = vim.system
	end)

	after_each(function()
		vim.fn.executable = original_executable
		vim.system = original_system
		health.reset_cache()
	end)

	it("reports all dependencies available", function()
		vim.fn.executable = function(bin)
			if bin == "wolframscript" or bin == "python3" then
				return 1
			end
			return 0
		end
		vim.system = function(cmd, _, cb)
			local name = cmd[1]
			if name == "wolframscript" then
				cb({ code = 0, stdout = "13.1.0\n", stderr = "" })
			elseif name == "python3" and cmd[2] == "-c" then
				cb({
					code = 0,
					stdout = '{"python":"3.11.0","numpy":"1.23.5","sympy":"1.12","matplotlib":"3.6.3"}',
					stderr = "",
				})
			elseif name == "python3" and cmd[2] == "-V" then
				cb({ code = 0, stdout = "Python 3.11.0\n", stderr = "" })
			else
				cb({ code = -1, stdout = "", stderr = "" })
			end
			return {}
		end

		local report
		health.check_dependencies(function(r)
			report = r
		end)
		wait_for(function()
			return report ~= nil
		end, 200)
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
		vim.system = function(_, _, cb)
			cb({ code = -1, stdout = "", stderr = "" })
			return {}
		end

		local report
		health.check_dependencies(function(r)
			report = r
		end)
		wait_for(function()
			return report ~= nil
		end, 200)
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
