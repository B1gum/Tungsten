-- tungsten/tests/unit/core/persistent_variable_pipeline_spec.lua
-- Unit tests for the persistent variable definition and evaluation pipeline.
-------------------------------------------------------------------------------

package.path = './lua/?.lua;./lua/?/init.lua;' .. package.path

local luassert_spy_table = require 'luassert.spy'
local match = require 'luassert.match'
local helpers = require 'tests.helpers'
local mock_utils = helpers.mock_utils
local vim_test_env = helpers.vim_test_env

describe("Tungsten Persistent Variable Pipeline", function()
  local commands_module

  local mock_parser
  local mock_wolfram_backend
  local current_visual_selection_value = ""
  local get_visual_selection_call_count = 0
  local mock_insert_result_util
  local mock_logger
  local mock_config
  local mock_state

  local original_jobstart

  local modules_to_reset = {
    'tungsten.core.commands',
    'tungsten.core.engine',
    'tungsten.core.parser',
    'tungsten.backends.wolfram',
    'tungsten.util.selection',
    'tungsten.util.insert_result',
    'tungsten.config',
    'tungsten.state',
    'tungsten.util.logger',
  }

  before_each(function()
    vim_test_env.setup()

    original_jobstart = _G.vim.fn.jobstart
    _G.vim.fn.jobstart = luassert_spy_table.new(function() return 1 end)

    mock_parser = mock_utils.mock_module('tungsten.core.parser', {
      parse = function(latex_str)
        if string.find(latex_str, "error") then return nil end
        return { type = "expression", latex = latex_str, id = "ast_for_" .. latex_str:gsub("%W", "") }
      end
    })

    mock_wolfram_backend = mock_utils.mock_module('tungsten.backends.wolfram', {
      to_string = function(ast)
        if not ast then return "Error: nil AST" end
        return "wolfram(" .. (ast.latex or ast.id or "unknown_ast") .. ")"
      end
    })

    current_visual_selection_value = "" 
    get_visual_selection_call_count = 0
    package.loaded['tungsten.util.selection'] = {
        get_visual_selection = function()
            get_visual_selection_call_count = get_visual_selection_call_count + 1
            return current_visual_selection_value
        end
    }

    mock_insert_result_util = mock_utils.mock_module('tungsten.util.insert_result', {
      insert_result = luassert_spy_table.new(function() end)
    })

    mock_logger = mock_utils.mock_module('tungsten.util.logger', {
      notify = luassert_spy_table.new(function() end),
      levels = { ERROR = 1, WARN = 2, INFO = 3, DEBUG = 4 }
    })

    mock_config = mock_utils.mock_module('tungsten.config', {
      wolfram_path = "mock_wolframscript",
      numeric_mode = false,
      debug = false,
      cache_enabled = false,
      persistent_variable_assignment_operator = ":=",
      wolfram_timeout_ms = 1000
    })

    mock_state = mock_utils.mock_module('tungsten.state', {
      persistent_variables = {},
      cache = {},
      active_jobs = {}
    })

    mock_utils.reset_modules({'tungsten.core.commands', 'tungsten.core.engine'})
    commands_module = require("tungsten.core.commands")
  end)

  after_each(function()
    _G.vim.fn.jobstart = original_jobstart
    vim_test_env.teardown()
    mock_utils.reset_modules(modules_to_reset)
  end)

  local function simulate_wolfram_eval(job_id, stdout_lines, exit_code)
    if #_G.vim.fn.jobstart.calls == 0 then
        error("simulate_wolfram_eval: vim.fn.jobstart was not called before simulating eval.")
    end
    local job_options = _G.vim.fn.jobstart.calls[#_G.vim.fn.jobstart.calls].vals[2]
    if job_options and job_options.on_stdout and stdout_lines then
      job_options.on_stdout(job_id, stdout_lines, 1)
    end
    if job_options and job_options.on_exit then
      job_options.on_exit(job_id, exit_code or 0, 1)
    end
  end

  describe("Full Persistent Variable Definition and Evaluation Pipeline", function()
    it("should define a variable and then use it in an evaluation", function()
      current_visual_selection_value = "x := 1+1"
      commands_module.define_persistent_variable_command({})
      assert.are.equal(1, get_visual_selection_call_count); get_visual_selection_call_count = 0

      assert.spy(mock_parser.parse).was.called_with("1+1")
      local expected_wolfram_def = "wolfram(1+1)"
      assert.are.same(expected_wolfram_def, mock_state.persistent_variables["x"])
      assert.spy(mock_logger.notify).was.called_with(
        "Tungsten: Defined persistent variable 'x' as '" .. expected_wolfram_def .. "'.",
        mock_logger.levels.INFO,
        match.is_table()
      )

      current_visual_selection_value = "x * 2"
      _G.vim.fn.jobstart:clear() 
      commands_module.tungsten_eval_command({})
      assert.are.equal(1, get_visual_selection_call_count); get_visual_selection_call_count = 0

      assert.spy(mock_parser.parse).was.called_with("x * 2")
      local ast_for_eval = { type = "expression", latex = "x * 2", id = "ast_for_" .. ("x * 2"):gsub("%W", "") }
      assert.spy(mock_wolfram_backend.to_string).was.called_with(ast_for_eval)

      assert.spy(_G.vim.fn.jobstart).was.called(1)
      local jobstart_args = _G.vim.fn.jobstart.calls[1].vals[1]

      local expected_code_after_substitution = "wolfram((wolfram(1+1)) * 2)"

      assert.are.same({mock_config.wolfram_path, "-code", expected_code_after_substitution}, jobstart_args)

      local wolfram_result = "ComputedResultFromX*2"
      simulate_wolfram_eval(1, {wolfram_result})
      assert.spy(mock_insert_result_util.insert_result).was.called_with(wolfram_result)
    end)

    it("should define multiple variables and use them in a dependent evaluation", function()
      current_visual_selection_value = "a := 5"
      commands_module.define_persistent_variable_command({})
      assert.are.equal(1, get_visual_selection_call_count); get_visual_selection_call_count = 0
      assert.are.same("wolfram(5)", mock_state.persistent_variables["a"])

      current_visual_selection_value = "b := a + 1"
      commands_module.define_persistent_variable_command({})
      assert.are.equal(1, get_visual_selection_call_count); get_visual_selection_call_count = 0
      assert.are.same("wolfram(a + 1)", mock_state.persistent_variables["b"]) 

      current_visual_selection_value = "b * 2"
      _G.vim.fn.jobstart:clear()
      mock_insert_result_util.insert_result:clear()
      commands_module.tungsten_eval_command({})
      assert.are.equal(1, get_visual_selection_call_count); get_visual_selection_call_count = 0

      local ast_for_eval = { type = "expression", latex = "b * 2", id = "ast_for_" .. ("b * 2"):gsub("%W", "") }
      assert.spy(mock_wolfram_backend.to_string).was.called_with(ast_for_eval)
      assert.spy(_G.vim.fn.jobstart).was.called(1)

      local jobstart_args = _G.vim.fn.jobstart.calls[1].vals[1]
      local expected_wolfram_code = "wolfram((wolfram((wolfram(5)) + 1)) * 2)"

      assert.are.same({mock_config.wolfram_path, "-code", expected_wolfram_code}, jobstart_args)

      local wolfram_result = "ComputedResultFromB*2"
      simulate_wolfram_eval(1, {wolfram_result})
      assert.spy(mock_insert_result_util.insert_result).was.called_with(wolfram_result)
    end)

    it("should use the latest definition if a variable is redefined", function()
      current_visual_selection_value = "y := 10"
      commands_module.define_persistent_variable_command({})
      assert.are.equal(1, get_visual_selection_call_count); get_visual_selection_call_count = 0
      assert.are.same("wolfram(10)", mock_state.persistent_variables["y"])

      current_visual_selection_value = "y + 5"
      _G.vim.fn.jobstart:clear()
      commands_module.tungsten_eval_command({})
      assert.are.equal(1, get_visual_selection_call_count); get_visual_selection_call_count = 0
      local jobstart_args1 = _G.vim.fn.jobstart.calls[1].vals[1]
      assert.are.same({mock_config.wolfram_path, "-code", "wolfram((wolfram(10)) + 5)"}, jobstart_args1)
      simulate_wolfram_eval(1, {"15"}) 

      current_visual_selection_value = "y := 20"
      commands_module.define_persistent_variable_command({})
      assert.are.equal(1, get_visual_selection_call_count); get_visual_selection_call_count = 0
      assert.are.same("wolfram(20)", mock_state.persistent_variables["y"])

      current_visual_selection_value = "y + 5"
      _G.vim.fn.jobstart:clear()
      commands_module.tungsten_eval_command({})
      assert.are.equal(1, get_visual_selection_call_count); get_visual_selection_call_count = 0
      local jobstart_args2 = _G.vim.fn.jobstart.calls[1].vals[1]
      assert.are.same({mock_config.wolfram_path, "-code", "wolfram((wolfram(20)) + 5)"}, jobstart_args2)
      simulate_wolfram_eval(1, {"25"})
      assert.spy(mock_insert_result_util.insert_result).was.called_with("25")
    end)

    it("should evaluate an expression without substitution if variable is not defined", function()
      mock_state.persistent_variables = {} 
      current_visual_selection_value = "z / 2"
      commands_module.tungsten_eval_command({})
      assert.are.equal(1, get_visual_selection_call_count); get_visual_selection_call_count = 0

      assert.spy(_G.vim.fn.jobstart).was.called(1)
      local jobstart_args = _G.vim.fn.jobstart.calls[1].vals[1]
      assert.are.same({mock_config.wolfram_path, "-code", "wolfram(z / 2)"}, jobstart_args)
      simulate_wolfram_eval(1, {"ResultFromZ/2"})
      assert.spy(mock_insert_result_util.insert_result).was.called_with("ResultFromZ/2")
    end)

    it("should respect 'persistent_variable_assignment_operator' from config ('=')", function()
      mock_config.persistent_variable_assignment_operator = "="
      mock_utils.reset_modules({'tungsten.core.commands'})
      commands_module = require("tungsten.core.commands")

      current_visual_selection_value = "v = 3"
      commands_module.define_persistent_variable_command({})
      assert.are.equal(1, get_visual_selection_call_count); get_visual_selection_call_count = 0
      assert.are.same("wolfram(3)", mock_state.persistent_variables["v"])

      current_visual_selection_value = "v * v"
      _G.vim.fn.jobstart:clear()
      commands_module.tungsten_eval_command({})
      assert.are.equal(1, get_visual_selection_call_count); get_visual_selection_call_count = 0
      local jobstart_args = _G.vim.fn.jobstart.calls[1].vals[1]
      assert.are.same({mock_config.wolfram_path, "-code", "wolfram((wolfram(3)) * (wolfram(3)))"}, jobstart_args)
      simulate_wolfram_eval(1, {"9"})
      assert.spy(mock_insert_result_util.insert_result).was.called_with("9")
    end)
  end)
end)
