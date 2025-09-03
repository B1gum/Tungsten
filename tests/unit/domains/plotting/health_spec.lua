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
                vim.fn.jobstart = function(_, opts)
                        if opts.on_stdout then
                                opts.on_stdout(nil, { '{"matplotlib": true, "sympy": true}', "" })
                        end
                        if opts.on_exit then
                                opts.on_exit(nil, 0)
                        end
                        return 1
                end
                vim.fn.jobwait = function(_) return { 0 } end

                local report = health.check_dependencies()
                assert.is_true(report.wolframscript)
                assert.is_true(report.python)
                assert.is_true(report.matplotlib)
                assert.is_true(report.sympy)
        end)

        it("handles missing python", function()
                vim.fn.executable = function(bin)
                        if bin == "wolframscript" then
                                return 0
                        end
                        return 0
                end
                vim.fn.jobstart = function() return -1 end
                vim.fn.jobwait = function() return { -1 } end

                local report = health.check_dependencies()
                assert.is_false(report.wolframscript)
                assert.is_false(report.python)
                assert.is_false(report.matplotlib)
                assert.is_false(report.sympy)
        end)
end)
