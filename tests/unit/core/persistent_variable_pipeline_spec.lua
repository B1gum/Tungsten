-- tungsten/tests/unit/core/persistent_variable_pipeline_spec.lua
-- Unit tests for the persistent variable definition and evaluation pipeline.

local spy = require "luassert.spy"
local match = require "luassert.match"
local mock_utils = require "tests.helpers.mock_utils"

describe("Tungsten Persistent Variable Pipeline", function()
  local commands_module

  local mock_parser_module
  local mock_wolfram_backend_module
  local mock_selection_module
  local mock_insert_result_util_module
  local mock_logger_module
  local mock_config_module
  local mock_state_module

  local mock_parser_parse_spy
  local mock_ast_to_wolfram_spy
  local mock_selection_get_visual_selection_spy
  local mock_insert_result_insert_result_spy
  local mock_logger_notify_spy
  local mock_async_run_job_spy
  
  local original_require

  local current_visual_selection_text
  local get_visual_selection_call_count

  local modules_to_clear_from_cache = {
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
    mock_parser_module = {}
    mock_wolfram_backend_module = {}
    mock_selection_module = {}
    mock_insert_result_util_module = {}
    mock_logger_module = {}
    mock_config_module = {
      wolfram_path = "mock_wolframscript",
      numeric_mode = false,
      debug = false,
      cache_enabled = false,
      persistent_variable_assignment_operator = ":=",
      wolfram_timeout_ms = 1000
    }
    mock_state_module = {
      persistent_variables = {},
      cache = {},
      active_jobs = {}
    }

    original_require = _G.require

    _G.require = function(module_path)
      if module_path == 'tungsten.core.parser' then return mock_parser_module end
      if module_path == 'tungsten.backends.wolfram' then return mock_wolfram_backend_module end
      if module_path == 'tungsten.util.selection' then return mock_selection_module end
      if module_path == 'tungsten.util.insert_result' then return mock_insert_result_util_module end
      if module_path == 'tungsten.util.logger' then return mock_logger_module end
      if module_path == 'tungsten.config' then return mock_config_module end
      if module_path == 'tungsten.state' then return mock_state_module end

      if package.loaded[module_path] then return package.loaded[module_path] end
      return original_require(module_path)
    end

    mock_utils.reset_modules(modules_to_clear_from_cache)

    mock_parser_parse_spy = spy.new(function(latex_str)
      if string.find(latex_str, "error") then return nil end
      return { type = "expression", latex = latex_str, id = "ast_for_" .. latex_str:gsub("%W", "") }
    end)
    mock_parser_module.parse = mock_parser_parse_spy

    mock_ast_to_wolfram_spy = spy.new(function(ast)
      if not ast then return "Error: nil AST" end
      return "wolfram(" .. (ast.latex or ast.id or "unknown_ast") .. ")"
    end)
    mock_wolfram_backend_module.ast_to_wolfram = mock_ast_to_wolfram_spy

    current_visual_selection_text = ""
    get_visual_selection_call_count = 0
    mock_selection_get_visual_selection_spy = spy.new(function()
        get_visual_selection_call_count = get_visual_selection_call_count + 1
        return current_visual_selection_text
    end)
    mock_selection_module.get_visual_selection = mock_selection_get_visual_selection_spy

    mock_insert_result_insert_result_spy = spy.new(function() end)
    mock_insert_result_util_module.insert_result = mock_insert_result_insert_result_spy

    mock_logger_notify_spy = spy.new(function () end)
    mock_logger_module.notify = mock_logger_notify_spy
    mock_logger_module.levels = { ERROR = 1, WARN = 2, INFO = 3, DEBUG = 4 }
    mock_logger_module.debug = function(t,m) mock_logger_notify_spy(m, mock_logger_module.levels.DEBUG, { title = t }) end
    mock_logger_module.info = function(t,m) mock_logger_notify_spy(m, mock_logger_module.levels.INFO, { title = t }) end
    mock_logger_module.warn = function(t,m) mock_logger_notify_spy(m, mock_logger_module.levels.WARN, { title = t }) end
    mock_logger_module.error = function(t,m) mock_logger_notify_spy(m, mock_logger_module.levels.ERROR, { title = t }) end

    mock_async_run_job_spy = spy.new(function(cmd, opts)
        if opts.on_exit then opts.on_exit(1, "result", "") end
        return { id = 1, cancel = function() end, is_active = function() return false end }
    end)
    package.loaded['tungsten.util.async'] = { run_job = mock_async_run_job_spy }

    package.loaded['tungsten.core.commands'] = nil
    package.loaded['tungsten.core.engine'] = nil
    commands_module = require("tungsten.core.commands")
  end)

  after_each(function()
    _G.require = original_require

    if mock_parser_parse_spy and mock_parser_parse_spy.clear then mock_parser_parse_spy:clear() end
    if mock_ast_to_wolfram_spy and mock_ast_to_wolfram_spy.clear then mock_ast_to_wolfram_spy:clear() end
    if mock_selection_get_visual_selection_spy and mock_selection_get_visual_selection_spy.clear then mock_selection_get_visual_selection_spy:clear() end
    if mock_insert_result_insert_result_spy and mock_insert_result_insert_result_spy.clear then mock_insert_result_insert_result_spy:clear() end
    if mock_logger_notify_spy and mock_logger_notify_spy.clear then mock_logger_notify_spy:clear() end
    if mock_async_run_job_spy and mock_async_run_job_spy.clear then mock_async_run_job_spy:clear() end

    mock_utils.reset_modules(modules_to_clear_from_cache)
  end)

  local function simulate_wolfram_eval(stdout_lines, exit_code)
    if #mock_async_run_job_spy.calls == 0 then
        error("simulate_wolfram_eval: async.run_job was not called before simulating eval.")
    end
    local job_options = mock_async_run_job_spy.calls[#mock_async_run_job_spy.calls].vals[2]
    if job_options and job_options.on_exit then
      job_options.on_exit(exit_code or 0, stdout_lines and table.concat(stdout_lines, "\n") or "", "")
    end
  end

  describe("Full Persistent Variable Definition and Evaluation Pipeline", function()
    it("should define a variable and then use it in an evaluation", function()
      current_visual_selection_text = "x := 1+1"
      commands_module.define_persistent_variable_command({})
      assert.are.equal(1, get_visual_selection_call_count); get_visual_selection_call_count = 0

      assert.spy(mock_parser_parse_spy).was.called_with("1+1")
      local expected_wolfram_def = "wolfram(1+1)"
      assert.are.same(expected_wolfram_def, mock_state_module.persistent_variables["x"])
      assert.spy(mock_logger_notify_spy).was.called_with(
        "Tungsten: Defined persistent variable 'x' as '" .. expected_wolfram_def .. "'.",
        mock_logger_module.levels.INFO,
        match.is_table()
      )

      current_visual_selection_text = "x * 2"
      commands_module.tungsten_evaluate_command({})
      assert.are.equal(1, get_visual_selection_call_count); get_visual_selection_call_count = 0

      assert.spy(mock_parser_parse_spy).was.called_with("x * 2")
      local ast_for_eval = { type = "expression", latex = "x * 2", id = "ast_for_" .. ("x * 2"):gsub("%W", "") }
      assert.spy(mock_ast_to_wolfram_spy).was.called_with(ast_for_eval)

      assert.spy(mock_async_run_job_spy).was.called(1)
      local cmd_args = mock_async_run_job_spy.calls[1].vals[1]
      local expected_code_after_substitution = "ToString[TeXForm[wolfram((wolfram(1+1)) * 2)], CharacterEncoding -> \"UTF8\"]"
      assert.are.same(mock_config_module.wolfram_path, cmd_args[1])
      assert.are.same(expected_code_after_substitution, cmd_args[3])

      local wolfram_result = "ComputedResultFromX*2"
      simulate_wolfram_eval({wolfram_result}, 0)
      assert.spy(mock_insert_result_insert_result_spy).was.called_with(wolfram_result)
    end)

    it("should define multiple variables and use them in a dependent evaluation", function()
      current_visual_selection_text = "a := 5"
      commands_module.define_persistent_variable_command({})
      assert.are.equal(1, get_visual_selection_call_count); get_visual_selection_call_count = 0
      assert.are.same("wolfram(5)", mock_state_module.persistent_variables["a"])

      current_visual_selection_text = "b := a + 1"
      commands_module.define_persistent_variable_command({})
      assert.are.equal(1, get_visual_selection_call_count); get_visual_selection_call_count = 0
      assert.are.same("wolfram(a + 1)", mock_state_module.persistent_variables["b"]) 

      current_visual_selection_text = "b * 2"
      mock_async_run_job_spy:clear()
      mock_insert_result_insert_result_spy:clear()
      commands_module.tungsten_evaluate_command({})
      assert.are.equal(1, get_visual_selection_call_count); get_visual_selection_call_count = 0

      assert.spy(mock_async_run_job_spy).was.called(1)
      local cmd_args = mock_async_run_job_spy.calls[1].vals[1]
      local expected_wolfram_code = "ToString[TeXForm[wolfram((wolfram((wolfram(5)) + 1)) * 2)], CharacterEncoding -> \"UTF8\"]"
      assert.are.same(expected_wolfram_code, cmd_args[3])

      local wolfram_result = "ComputedResultFromB*2"
      simulate_wolfram_eval({wolfram_result}, 0)
      assert.spy(mock_insert_result_insert_result_spy).was.called_with(wolfram_result)
    end)

    it("should use the latest definition if a variable is redefined", function()
      current_visual_selection_text = "y := 10"
      commands_module.define_persistent_variable_command({})
      assert.are.equal(1, get_visual_selection_call_count); get_visual_selection_call_count = 0
      assert.are.same("wolfram(10)", mock_state_module.persistent_variables["y"])

      current_visual_selection_text = "y + 5"
      mock_async_run_job_spy:clear()
      commands_module.tungsten_evaluate_command({})
      assert.are.equal(1, get_visual_selection_call_count); get_visual_selection_call_count = 0
      local cmd_args1 = mock_async_run_job_spy.calls[1].vals[1]
      assert.are.same("ToString[TeXForm[wolfram((wolfram(10)) + 5)], CharacterEncoding -> \"UTF8\"]", cmd_args1[3])
      simulate_wolfram_eval({"15"}, 0)

      current_visual_selection_text = "y := 20"
      commands_module.define_persistent_variable_command({})
      assert.are.equal(1, get_visual_selection_call_count); get_visual_selection_call_count = 0
      assert.are.same("wolfram(20)", mock_state_module.persistent_variables["y"])

      current_visual_selection_text = "y + 5"
      mock_async_run_job_spy:clear()
      mock_insert_result_insert_result_spy:clear()
      commands_module.tungsten_evaluate_command({})
      assert.are.equal(1, get_visual_selection_call_count); get_visual_selection_call_count = 0
      local cmd_args2 = mock_async_run_job_spy.calls[1].vals[1]
      assert.are.same("ToString[TeXForm[wolfram((wolfram(20)) + 5)], CharacterEncoding -> \"UTF8\"]", cmd_args2[3])
      simulate_wolfram_eval({"25"}, 0)
      assert.spy(mock_insert_result_insert_result_spy).was.called_with("25")
    end)

    it("should evaluate an expression without substitution if variable is not defined", function()
      mock_state_module.persistent_variables = {}
      current_visual_selection_text = "z / 2"
      mock_async_run_job_spy:clear()
      mock_insert_result_insert_result_spy:clear()
      commands_module.tungsten_evaluate_command({})
      assert.are.equal(1, get_visual_selection_call_count); get_visual_selection_call_count = 0

      assert.spy(mock_async_run_job_spy).was.called(1)
      local cmd_args = mock_async_run_job_spy.calls[1].vals[1]
      assert.are.same("ToString[TeXForm[wolfram(z / 2)], CharacterEncoding -> \"UTF8\"]", cmd_args[3])
      simulate_wolfram_eval({"ResultFromZ/2"}, 0)
      assert.spy(mock_insert_result_insert_result_spy).was.called_with("ResultFromZ/2")
    end)

    it("should respect 'persistent_variable_assignment_operator' from config ('=')", function()
      mock_config_module.persistent_variable_assignment_operator = "="
      package.loaded['tungsten.core.commands'] = nil
      commands_module = require("tungsten.core.commands")

      current_visual_selection_text = "v = 3"
      commands_module.define_persistent_variable_command({})
      assert.are.equal(1, get_visual_selection_call_count); get_visual_selection_call_count = 0
      assert.are.same("wolfram(3)", mock_state_module.persistent_variables["v"])

      current_visual_selection_text = "v * v"
      mock_async_run_job_spy:clear()
      mock_insert_result_insert_result_spy:clear()
      commands_module.tungsten_evaluate_command({})
      assert.are.equal(1, get_visual_selection_call_count); get_visual_selection_call_count = 0
      local cmd_args = mock_async_run_job_spy.calls[1].vals[1]
      assert.are.same("ToString[TeXForm[wolfram((wolfram(3)) * (wolfram(3)))], CharacterEncoding -> \"UTF8\"]", cmd_args[3])
      simulate_wolfram_eval({"9"}, 0)
      assert.spy(mock_insert_result_insert_result_spy).was.called_with("9")

      mock_config_module.persistent_variable_assignment_operator = ":="
    end)

    it("should respect 'persistent_variable_assignment_operator' from config (':=')", function()
      mock_config_module.persistent_variable_assignment_operator = ":="
      package.loaded['tungsten.core.commands'] = nil
      commands_module = require("tungsten.core.commands")

      current_visual_selection_text = "w := 4"
      commands_module.define_persistent_variable_command({})
      assert.are.equal(1, get_visual_selection_call_count); get_visual_selection_call_count = 0
      assert.are.same("wolfram(4)", mock_state_module.persistent_variables["w"])

      current_visual_selection_text = "w + w"
      mock_async_run_job_spy:clear()
      mock_insert_result_insert_result_spy:clear()
      commands_module.tungsten_evaluate_command({})
      assert.are.equal(1, get_visual_selection_call_count); get_visual_selection_call_count = 0
      local cmd_args = mock_async_run_job_spy.calls[1].vals[1]
      assert.are.same("ToString[TeXForm[wolfram((wolfram(4)) + (wolfram(4)))], CharacterEncoding -> \"UTF8\"]", cmd_args[3])
      simulate_wolfram_eval({"8"}, 0)
      assert.spy(mock_insert_result_insert_result_spy).was.called_with("8")
    end)
  end)
end)
