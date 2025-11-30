local spy = require("luassert.spy")
local mock_utils = require("tests.helpers.mock_utils")

describe("Linear Algebra commands", function()
	local commands
	local mock_workflow
	local mock_definitions

	local modules_to_reset = {
		"tungsten.domains.linear_algebra.commands",
	}

	local original_require

	before_each(function()
		mock_workflow = { run = spy.new(function() end) }
		mock_definitions = {
			TungstenGaussEliminate = { id = "gauss" },
			TungstenLinearIndependent = { id = "li" },
			TungstenRank = { id = "rank" },
			TungstenEigenvalue = { id = "eigval" },
			TungstenEigenvector = { id = "eigvec" },
			TungstenEigensystem = { id = "eigs" },
		}

		original_require = _G.require
		_G.require = function(module_path)
			if module_path == "tungsten.core.workflow" then
				return mock_workflow
			end
			if module_path == "tungsten.domains.linear_algebra.command_definitions" then
				return mock_definitions
			end
			return original_require(module_path)
		end

		mock_utils.reset_modules(modules_to_reset)
		commands = require("tungsten.domains.linear_algebra.commands")
	end)

	after_each(function()
		_G.require = original_require
		mock_utils.reset_modules(modules_to_reset)
	end)

	local function expect_run(command_fn, definition_key)
		mock_workflow.run:clear()
		command_fn()
		assert.spy(mock_workflow.run).was.called_with(mock_definitions[definition_key])
	end

	it("invokes workflow with each command definition", function()
		expect_run(commands.tungsten_gauss_eliminate_command, "TungstenGaussEliminate")
		expect_run(commands.tungsten_linear_independent_command, "TungstenLinearIndependent")
		expect_run(commands.tungsten_rank_command, "TungstenRank")
		expect_run(commands.tungsten_eigenvalue_command, "TungstenEigenvalue")
		expect_run(commands.tungsten_eigenvector_command, "TungstenEigenvector")
		expect_run(commands.tungsten_eigensystem_command, "TungstenEigensystem")
	end)

	it("exposes command metadata for registration", function()
		local names = {}
		for _, cmd in ipairs(commands.commands) do
			names[#names + 1] = cmd.name
			assert.is_function(cmd.func)
			assert.is_true(cmd.opts.range)
			assert.is_not_nil(cmd.opts.desc)
		end

		assert.are.same({
			"TungstenGaussEliminate",
			"TungstenLinearIndependent",
			"TungstenRank",
			"TungstenEigenvalue",
			"TungstenEigenvector",
			"TungstenEigensystem",
		}, names)
	end)
end)
