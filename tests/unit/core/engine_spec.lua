-- tests/unit/core/engine_spec.lua
-- Unit tests for the Tungsten evaluation engine.
---------------------------------------------------------------------

package.path = './lua/?.lua;./lua/?/init.lua;' .. package.path

local spy = require 'luassert.spy'
local match = require 'luassert.match'
local helpers = require 'tests.helpers'

local function fresh_jobstart_spy()
  local id_counter = 0
  local spy_wrapper = {}
  local actual_spy = spy.new(function(_, _)
    id_counter = id_counter + 1
    spy_wrapper.last_returned_id = id_counter
    return id_counter
  end)
  spy_wrapper.fn = actual_spy
  spy_wrapper.last_returned_id = nil

  setmetatable(spy_wrapper, {
    __call = function(tbl, ...)
      return tbl.fn(...)
    end,
    __index = function(tbl, key)
      if key == "last_returned_id" then
        return rawget(tbl, key)
      elseif key == "calls" or key == "called_with" or key == "was_called_with" or
             key == "called" or key == "was_called" or key == "clear" or
             key == "revert" or key == "is_spy" or key == "target_function" then
        return tbl.fn[key]
      end
      return rawget(tbl, key)
    end,
    __newindex = function(tbl, key, value)
        if key == "last_returned_id" or key == "fn" then
            rawset(tbl, key, value)
        else
            tbl.fn[key] = value
        end
    end
  })
  return spy_wrapper
end


describe("tungsten.core.engine", function()
  local engine
  local mock_parser_module
  local mock_wolfram_backend_module
  local mock_config_module
  local mock_state_module
  local mock_logger_module
  local mock_vim_loop_timer
  local captured_timer_callback
  local current_mock_time

  local modules_to_reset = {
    'tungsten.core.engine',
    'tungsten.core.parser',
    'tungsten.backends.wolfram',
    'tungsten.config',
    'tungsten.state',
    'tungsten.util.logger',
  }

  before_each(function()
    mock_parser_module = helpers.mock_utils.mock_module('tungsten.core.parser', {
      parse = spy.new(function(input_str)
        if input_str == "valid_latex" then
          return { type = "Expression", value = "parsed_valid_latex" }
        elseif input_str == "error_latex" then
          return nil
        else
          return { type = "Expression", value = "parsed_" .. input_str }
        end
      end),
    })

    mock_wolfram_backend_module = helpers.mock_utils.mock_module('tungsten.backends.wolfram', {
      to_string = spy.new(function(ast)
        if ast and ast.type == "ErrorAST" then
          error("lua/tungsten/backends/wolfram.lua:XX: AST to Wolfram conversion error")
        elseif ast and ast.value == "parsed_valid_latex" then
          return "wolfram_code_for_valid_latex"
        elseif ast and ast.value then
          return "wolfram_code_for_" .. ast.value
        end
        return "mock_wolfram_code_default_fallback"
      end),
    })

    mock_config_module = helpers.mock_utils.mock_module('tungsten.config', {
      wolfram_path = "mock_wolframscript",
      numeric_mode = false,
      debug = false,
      cache_enabled = true,
      domains = { "arithmetic" },
      wolfram_timeout_ms = 10000
    })

    mock_state_module = helpers.mock_utils.mock_module('tungsten.state', {
      cache = {},
      active_jobs = {},
      persistent_variables = {}
    })

    mock_logger_module = helpers.mock_utils.mock_module('tungsten.util.logger', {
      notify = spy.new(function() end),
      levels = { ERROR = 1, WARN = 2, INFO = 3, DEBUG = 4 }
    })

    captured_timer_callback = nil
    mock_vim_loop_timer = {
        start = spy.new(function(timer_obj, timeout, interval, callback)
            captured_timer_callback = callback
        end),
        stop = spy.new(function() end),
        close = spy.new(function() end),
        again = spy.new(function() end),
        is_active = spy.new(function() return captured_timer_callback ~= nil end),
        trigger = function()
            if captured_timer_callback then
                local cb_to_call = captured_timer_callback
                cb_to_call()
            end
        end
    }
    current_mock_time = 1234567890
    helpers.vim_test_env.setup({
        deep_equal = function(a, b)
            return require('luassert.match').compare(a, b)
        end,
        loop = {
            now = spy.new(function() return current_mock_time end),
            new_timer = spy.new(function() return mock_vim_loop_timer end),
        }
    })
    helpers.mock_utils.reset_modules({'tungsten.core.engine'})
    engine = require("tungsten.core.engine")
  end)

  after_each(function()
    helpers.vim_test_env.teardown()
    helpers.mock_utils.reset_modules(modules_to_reset)
  end)

  describe("evaluate_async(ast, numeric, callback)", function()
    local sample_ast_eval_async
    local callback_spy
    local actual_callback

    before_each(function()
      sample_ast_eval_async = { type = "Expression", value = "some_expression_for_eval_async" }
      callback_spy    = spy.new(function() end)
      actual_callback = function(...) callback_spy(...) end
      mock_config_module.cache_enabled = true
      mock_state_module.cache          = {}
      mock_state_module.active_jobs    = {}
      mock_state_module.persistent_variables = {}

      _G.vim.fn.jobstart = fresh_jobstart_spy()
      _G.vim.fn.jobstart:clear()
      mock_logger_module.notify:clear()

      mock_vim_loop_timer.start:clear()
      mock_vim_loop_timer.stop:clear()
      mock_vim_loop_timer.close:clear()
      captured_timer_callback = nil
      current_mock_time = 1234567890
    end)


    it("should successfully evaluate symbolically", function()
      engine.evaluate_async(sample_ast_eval_async, false, actual_callback)
      assert.spy(mock_wolfram_backend_module.to_string).was.called_with(sample_ast_eval_async)
      assert.spy(_G.vim.fn.jobstart.fn).was.called(1)
      local jobstart_args = _G.vim.fn.jobstart.fn.calls[1].vals[1]
      assert.are.same({ "mock_wolframscript", "-code", "wolfram_code_for_some_expression_for_eval_async" }, jobstart_args)
      local job_id = _G.vim.fn.jobstart.last_returned_id
      assert.is_not_nil(job_id, "Job ID not found for symbolic evaluation")
      local job_options = _G.vim.fn.jobstart.fn.calls[1].vals[2]
      job_options.on_stdout(job_id, { "symbolic_result" }, 1)
      job_options.on_exit(job_id, 0, 1)
      assert.spy(callback_spy).was.called_with("symbolic_result", nil)
    end)

    it("should successfully evaluate numerically, wrapping code with N[]", function()
      engine.evaluate_async(sample_ast_eval_async, true, actual_callback)
      assert.spy(mock_wolfram_backend_module.to_string).was.called_with(sample_ast_eval_async)
      assert.spy(_G.vim.fn.jobstart.fn).was.called(1)
      local jobstart_args = _G.vim.fn.jobstart.fn.calls[1].vals[1]
      assert.are.same({ "mock_wolframscript", "-code", "N[wolfram_code_for_some_expression_for_eval_async]" }, jobstart_args)
      local job_id = _G.vim.fn.jobstart.last_returned_id
      assert.is_not_nil(job_id, "Job ID not found for numeric evaluation")
      local job_options = _G.vim.fn.jobstart.fn.calls[1].vals[2]
      job_options.on_stdout(job_id, { "numeric_result" }, 1)
      job_options.on_exit(job_id, 0, 1)
      assert.spy(callback_spy).was.called_with("numeric_result", nil)
    end)

    it("should use global config.numeric_mode if 'numeric' param is false but global is true", function()
      mock_config_module.numeric_mode = true
      engine.evaluate_async(sample_ast_eval_async, false, actual_callback)
      assert.spy(_G.vim.fn.jobstart.fn).was.called(1)
      local jobstart_args = _G.vim.fn.jobstart.fn.calls[1].vals[1]
      assert.are.same({ "mock_wolframscript", "-code", "N[wolfram_code_for_some_expression_for_eval_async]" }, jobstart_args)
    end)

    it("should return cached result immediately if cache is enabled and item exists", function()
      mock_config_module.cache_enabled = true
      local expr_key = "wolfram_code_for_some_expression_for_eval_async::symbolic"
      mock_state_module.cache[expr_key] = "cached_symbolic_result"
      engine.evaluate_async(sample_ast_eval_async, false, actual_callback)
      assert.spy(callback_spy).was.called_with("cached_symbolic_result", nil)
      assert.spy(_G.vim.fn.jobstart.fn).was_not.called()
      assert.spy(mock_logger_module.notify).was.called_with("Tungsten: Result from cache.", mock_logger_module.levels.INFO, match.is_table())
    end)

    it("should start a job and cache the result if cache is enabled and item does not exist (cache miss)", function()
      mock_config_module.cache_enabled = true
      local expr_key = "wolfram_code_for_some_expression_for_eval_async::symbolic"
      engine.evaluate_async(sample_ast_eval_async, false, actual_callback)
      assert.spy(_G.vim.fn.jobstart.fn).was.called(1)
      local job_id = _G.vim.fn.jobstart.last_returned_id
      assert.is_not_nil(job_id, "Job ID not found for cache miss")
      local job_options = _G.vim.fn.jobstart.fn.calls[1].vals[2]
      job_options.on_stdout(job_id, { "new_symbolic_result" }, 1)
      job_options.on_exit(job_id, 0, 1)
      assert.spy(callback_spy).was.called_with("new_symbolic_result", nil)
      assert.are.equal("new_symbolic_result", mock_state_module.cache[expr_key])
    end)

    it("should always start a job and not use/store in cache if cache is disabled", function()
      mock_config_module.cache_enabled = false
      local expr_key = "wolfram_code_for_some_expression_for_eval_async::symbolic"
      mock_state_module.cache[expr_key] = "cached_symbolic_result_but_disabled"
      engine.evaluate_async(sample_ast_eval_async, false, actual_callback)
      assert.spy(_G.vim.fn.jobstart.fn).was.called(1)
      local job_id = _G.vim.fn.jobstart.last_returned_id
      assert.is_not_nil(job_id, "Job ID not found when cache disabled")
      local job_options = _G.vim.fn.jobstart.fn.calls[1].vals[2]
      job_options.on_stdout(job_id, { "fresh_result_no_cache" }, 1)
      job_options.on_exit(job_id, 0, 1)
      assert.spy(callback_spy).was.called_with("fresh_result_no_cache", nil)
      assert.are.equal("cached_symbolic_result_but_disabled", mock_state_module.cache[expr_key])
      assert.spy(callback_spy).was_not.called_with("cached_symbolic_result_but_disabled", nil)
    end)

    it("should invoke callback with error if AST to Wolfram code conversion fails", function()
      local error_ast = { type = "ErrorAST" }
      engine.evaluate_async(error_ast, false, actual_callback)
      assert.spy(mock_wolfram_backend_module.to_string).was.called_with(error_ast)
      local callback_args = callback_spy.calls[1].vals
      assert.is_nil(callback_args[1])
      assert.is_not_nil(callback_args[2] and string.find(callback_args[2], "Error converting AST to Wolfram code: ", 1, true))
      assert.is_not_nil(callback_args[2] and string.find(callback_args[2], "AST to Wolfram conversion error", 1, true))
      assert.spy(_G.vim.fn.jobstart.fn).was_not.called()
      assert.spy(mock_logger_module.notify).was.called_with(
        match.has_match("Tungsten: Error converting AST to Wolfram code:"),
        mock_logger_module.levels.ERROR,
        match.is_table()
      )
    end)

    it("should invoke callback with error if vim.fn.jobstart returns 0", function()
      _G.vim.fn.jobstart = spy.new(function() return 0 end)
      engine.evaluate_async(sample_ast_eval_async, false, actual_callback)
      assert.spy(callback_spy).was.called_with(nil, "Failed to start WolframScript job. (Reason: Invalid arguments to jobstart)")
      assert.spy(mock_logger_module.notify).was.called_with(
        "Tungsten: Failed to start WolframScript job. (Reason: Invalid arguments to jobstart)",
        mock_logger_module.levels.ERROR,
        match.is_table()
      )
    end)

    it("should invoke callback with error if vim.fn.jobstart returns -1", function()
      _G.vim.fn.jobstart = spy.new(function() return -1 end)
      engine.evaluate_async(sample_ast_eval_async, false, actual_callback)
      local expected_err_msg = "Failed to start WolframScript job. (Reason: Command 'mock_wolframscript' not found - is wolframscript in your PATH?)"
      assert.spy(callback_spy).was.called_with(nil, expected_err_msg)
      assert.spy(mock_logger_module.notify).was.called_with(
        "Tungsten: " .. expected_err_msg,
        mock_logger_module.levels.ERROR,
        match.is_table()
      )
    end)

    it("should invoke callback with error if WolframScript exits with non-zero code and stderr output", function()
      engine.evaluate_async(sample_ast_eval_async, false, actual_callback)
      assert.spy(_G.vim.fn.jobstart.fn).was.called(1)
      local job_id = _G.vim.fn.jobstart.last_returned_id
      assert.is_not_nil(job_id, "Job ID not found for stderr test")
      local job_options = _G.vim.fn.jobstart.fn.calls[1].vals[2]
      job_options.on_stderr(job_id, { "wolfram_error_output" }, 1)
      job_options.on_exit(job_id, 1, 1)
      assert.spy(callback_spy).was.called_with(nil, match.has_match(("WolframScript %%(Job %d%%) exited with code 1\nStderr: wolfram_error_output"):format(job_id)))
      assert.spy(mock_logger_module.notify).was.called_with(
        match.has_match(("Tungsten: WolframScript %%(Job %d%%) exited with code 1\nStderr: wolfram_error_output"):format(job_id)),
        mock_logger_module.levels.ERROR,
        match.is_table()
      )
    end)

     it("should invoke callback with error if WolframScript exits with non-zero code and stdout output (no stderr)", function()
      engine.evaluate_async(sample_ast_eval_async, false, actual_callback)
      assert.spy(_G.vim.fn.jobstart.fn).was.called(1)
      local job_id = _G.vim.fn.jobstart.last_returned_id
      assert.is_not_nil(job_id, "Job ID not found for stdout error test")
      local job_options = _G.vim.fn.jobstart.fn.calls[1].vals[2]
      job_options.on_stdout(job_id, { "some_stdout_content_on_error" }, 1)
      job_options.on_exit(job_id, 127, 1)
      assert.spy(callback_spy).was.called_with(nil, match.has_match(("WolframScript %%(Job %d%%) exited with code 127\nStdout %%(potentially error%%): some_stdout_content_on_error"):format(job_id)))
       assert.spy(mock_logger_module.notify).was.called_with(
        match.has_match(("Tungsten: WolframScript %%(Job %d%%) exited with code 127\nStdout %%(potentially error%%): some_stdout_content_on_error"):format(job_id)),
        mock_logger_module.levels.ERROR,
        match.is_table()
      )
    end)

    it("should log a notification and not start a new job if a job for the same expression is already in progress", function()
      local expr_key = "wolfram_code_for_some_expression_for_eval_async::symbolic"
      mock_state_module.active_jobs[99] = {
        expr_key = expr_key, bufnr = 1, code_sent = "wolfram_code_for_some_expression_for_eval_async", start_time = 12345,
      }
      engine.evaluate_async(sample_ast_eval_async, false, actual_callback)
      assert.spy(mock_logger_module.notify).was.called_with("Tungsten: Evaluation already in progress for this expression.", mock_logger_module.levels.INFO, match.is_table())
      assert.spy(_G.vim.fn.jobstart.fn).was_not.called()
      assert.spy(callback_spy).was_not.called()
    end)

    it("should add job to active_jobs on start and remove on exit", function()
      assert.is_true(_G.vim.tbl_isempty(mock_state_module.active_jobs))
      engine.evaluate_async(sample_ast_eval_async, false, actual_callback)
      assert.spy(_G.vim.fn.jobstart.fn).was.called(1)
      local job_id_from_return = _G.vim.fn.jobstart.last_returned_id
      assert.is_not_nil(job_id_from_return, "Job not added to active_jobs")
      assert.is_not_nil(mock_state_module.active_jobs[job_id_from_return])
      assert.are.equal("wolfram_code_for_some_expression_for_eval_async::symbolic", mock_state_module.active_jobs[job_id_from_return].expr_key)
      assert.are.equal(1, mock_state_module.active_jobs[job_id_from_return].bufnr)
      local job_options = _G.vim.fn.jobstart.fn.calls[1].vals[2]
      job_options.on_exit(job_id_from_return, 0, 1)
      assert.is_nil(mock_state_module.active_jobs[job_id_from_return])
    end)
  end)

  describe("Persistent Variable Substitution", function()
    local substitution_test_ast
    local callback_spy
    local actual_callback

    before_each(function()
      substitution_test_ast = { type = "Expression", value = "sub_test_value" }
      callback_spy = spy.new(function() end)
      actual_callback = function(...) callback_spy(...) end
      mock_state_module.persistent_variables = {}
      mock_state_module.cache = {}
      mock_config_module.debug = false

      _G.vim.fn.jobstart:clear()
      mock_logger_module.notify:clear()
      if mock_wolfram_backend_module.to_string.clear then
          mock_wolfram_backend_module.to_string:clear()
      end
      current_mock_time = 1234567890
    end)

    it("should substitute a single persistent variable", function()
      mock_state_module.persistent_variables["x"] = "10"
      mock_wolfram_backend_module.to_string = spy.new(function(ast_arg)
        if ast_arg == substitution_test_ast then return "x + y" end
        return "unexpected_ast_for_single_sub_test"
      end)

      engine.evaluate_async(substitution_test_ast, false, actual_callback)
      assert.spy(_G.vim.fn.jobstart.fn).was.called(1)
      local jobstart_args = _G.vim.fn.jobstart.fn.calls[1].vals[1]
      assert.are.same({ "mock_wolframscript", "-code", "(10) + y" }, jobstart_args)
      local expr_key = engine.get_cache_key("(10) + y", false)
      assert.are.equal("(10) + y::symbolic", expr_key)
    end)

    it("should substitute multiple persistent variables", function()
      mock_state_module.persistent_variables["x"] = "5"
      mock_state_module.persistent_variables["y"] = "(2+2)"
      mock_wolfram_backend_module.to_string = spy.new(function(ast_arg)
        if ast_arg == substitution_test_ast then return "x + y * x" end
        return "unexpected_ast_for_multi_sub_test"
      end)
      engine.evaluate_async(substitution_test_ast, false, actual_callback)
      assert.spy(_G.vim.fn.jobstart.fn).was.called(1)
      local jobstart_args = _G.vim.fn.jobstart.fn.calls[1].vals[1]
      assert.are.same({ "mock_wolframscript", "-code", "(5) + ((2+2)) * (5)" }, jobstart_args)
    end)

    it("should generate different cache keys for different variable definitions", function()
      mock_wolfram_backend_module.to_string = spy.new(function(ast_arg)
        if ast_arg == substitution_test_ast then return "varA + 1" end
        return "unexpected_ast_for_cache_key_test"
      end)

      mock_state_module.persistent_variables = { varA = "100" }
      engine.evaluate_async(substitution_test_ast, false, actual_callback)
      assert.spy(_G.vim.fn.jobstart.fn).was.called(1)
      local job_id1 = _G.vim.fn.jobstart.last_returned_id
      local job_options1 = _G.vim.fn.jobstart.fn.calls[1].vals[2]
      job_options1.on_stdout(job_id1, { "res1" }, 1); job_options1.on_exit(job_id1, 0, 1)
      local expr_key1 = engine.get_cache_key("(100) + 1", false)
      assert.are.equal("res1", mock_state_module.cache[expr_key1])

      _G.vim.fn.jobstart:clear()
      mock_state_module.persistent_variables = { varA = "200" }
      engine.evaluate_async(substitution_test_ast, false, actual_callback)
      assert.spy(_G.vim.fn.jobstart.fn).was.called(1)
      local job_id2 = _G.vim.fn.jobstart.last_returned_id
      local job_options2 = _G.vim.fn.jobstart.fn.calls[1].vals[2]
      job_options2.on_stdout(job_id2, { "res2" }, 1); job_options2.on_exit(job_id2, 0, 1)
      local expr_key2 = engine.get_cache_key("(200) + 1", false)
      assert.are.equal("res2", mock_state_module.cache[expr_key2])
      assert.are_not_equal(expr_key1, expr_key2)
    end)

    it("should correctly handle operator precedence with parentheses around substituted values", function()
      mock_state_module.persistent_variables["myVar"] = "1+1"
      mock_wolfram_backend_module.to_string = spy.new(function(ast_arg)
        if ast_arg == substitution_test_ast then return "myVar * 2" end
        return "unexpected_ast_for_precedence_test"
      end)
      engine.evaluate_async(substitution_test_ast, false, actual_callback)
      assert.spy(_G.vim.fn.jobstart.fn).was.called(1)
      local jobstart_args = _G.vim.fn.jobstart.fn.calls[1].vals[1]
      assert.are.same({ "mock_wolframscript", "-code", "(1+1) * 2" }, jobstart_args)
    end)

    it("should not substitute if variable name is part of a larger word/symbol", function()
      mock_state_module.persistent_variables["val"] = "3"
      mock_wolfram_backend_module.to_string = spy.new(function(ast_arg)
        if ast_arg == substitution_test_ast then return "eval + val + value + valX" end
        return "unexpected_ast_for_whole_word_test"
      end)
      engine.evaluate_async(substitution_test_ast, false, actual_callback)
      assert.spy(_G.vim.fn.jobstart.fn).was.called(1)
      local jobstart_args = _G.vim.fn.jobstart.fn.calls[1].vals[1]
      assert.are.same({ "mock_wolframscript", "-code", "eval + (3) + value + valX" }, jobstart_args)
    end)

    it("should handle substitution when persistent_variables map is empty", function()
      mock_state_module.persistent_variables = {}
      mock_wolfram_backend_module.to_string = spy.new(function(ast_arg)
        if ast_arg == substitution_test_ast then return "no_vars_here" end
        return "unexpected_ast_for_empty_vars_test"
      end)
      engine.evaluate_async(substitution_test_ast, false, actual_callback)
      assert.spy(_G.vim.fn.jobstart.fn).was.called(1)
      local jobstart_args = _G.vim.fn.jobstart.fn.calls[1].vals[1]
      assert.are.same({ "mock_wolframscript", "-code", "no_vars_here" }, jobstart_args)
    end)

    it("should handle substitution when persistent_variables is nil", function()
      mock_state_module.persistent_variables = nil
      mock_wolfram_backend_module.to_string = spy.new(function(ast_arg)
        if ast_arg == substitution_test_ast then return "nil_vars_map" end
        return "unexpected_ast_for_nil_vars_test"
      end)
      engine.evaluate_async(substitution_test_ast, false, actual_callback)
      assert.spy(_G.vim.fn.jobstart.fn).was.called(1)
      local jobstart_args = _G.vim.fn.jobstart.fn.calls[1].vals[1]
      assert.are.same({ "mock_wolframscript", "-code", "nil_vars_map" }, jobstart_args)
    end)

    it("should substitute longer variable names before shorter ones (e.g. 'xx' before 'x')", function()
        mock_state_module.persistent_variables["x"] = "1"
        mock_state_module.persistent_variables["xx"] = "100"
        mock_wolfram_backend_module.to_string = spy.new(function(ast_arg)
          if ast_arg == substitution_test_ast then return "xx + x" end
          return "unexpected_ast_for_sorting_sub_test"
        end)
        engine.evaluate_async(substitution_test_ast, false, actual_callback)
        assert.spy(_G.vim.fn.jobstart.fn).was.called(1)
        local jobstart_args = _G.vim.fn.jobstart.fn.calls[1].vals[1]
        assert.are.same({ "mock_wolframscript", "-code", "(100) + (1)" }, jobstart_args)
    end)

    it("should log substituted code if debug mode is on", function()
      mock_config_module.debug = true
      mock_state_module.persistent_variables["dbgVar"] = "DebugValue"
      mock_wolfram_backend_module.to_string = spy.new(function(ast_arg)
        if ast_arg == substitution_test_ast then return "Code + dbgVar" end
        return "unexpected_ast_for_debug_log_test"
      end)
      engine.evaluate_async(substitution_test_ast, false, actual_callback)
      assert.spy(mock_logger_module.notify).was.called_with(
        "Tungsten Debug: Code after persistent variable substitution: Code + (DebugValue)",
        mock_logger_module.levels.DEBUG,
        { title = "Tungsten Debug" }
      )
    end)

     it("should log 'no substitution' if debug mode is on and no vars were substituted", function()
      mock_config_module.debug = true
      mock_state_module.persistent_variables = { someOtherVar = "val" }
      mock_wolfram_backend_module.to_string = spy.new(function(ast_arg)
        if ast_arg == substitution_test_ast then return "CodeWithNoMatchingVars" end
        return "unexpected_ast_for_no_sub_debug_log_test"
      end)
      engine.evaluate_async(substitution_test_ast, false, actual_callback)
      assert.spy(mock_logger_module.notify).was.called_with(
        "Tungsten Debug: No persistent variable substitutions made.",
        mock_logger_module.levels.DEBUG,
        { title = "Tungsten Debug" }
      )
    end)
  end)

  describe("Timeout Mechanism", function()
    local timeout_test_ast
    local callback_spy
    local actual_callback

    before_each(function()
      timeout_test_ast = { type = "Expression", value = "timeout_expr_val" }
      callback_spy = spy.new(function() end)
      actual_callback = function(...) callback_spy(...) end
      mock_config_module.cache_enabled = false
      mock_state_module.active_jobs = {}
      _G.vim.fn.jobstart:clear()
      mock_logger_module.notify:clear()

      mock_vim_loop_timer.start:clear()
      mock_vim_loop_timer.stop:clear()
      mock_vim_loop_timer.close:clear()
      captured_timer_callback = nil
      current_mock_time = 1234567890
    end)

    it("should log a timeout message if the job exceeds the configured timeout", function()
      mock_config_module.wolfram_timeout_ms = 50
      engine.evaluate_async(timeout_test_ast, false, actual_callback)

      assert.spy(mock_vim_loop_timer.start).was.called(1)
      assert.spy(mock_vim_loop_timer.start).was.called_with(mock_vim_loop_timer, 50, 0, match.is_function())

      local job_id = _G.vim.fn.jobstart.last_returned_id
      assert.is_not_nil(job_id, "Job ID not found for timeout test")

      current_mock_time = current_mock_time + mock_config_module.wolfram_timeout_ms
      mock_vim_loop_timer.trigger()

      assert.spy(mock_logger_module.notify).was.called_with(
        ("Tungsten: Wolframscript job %d timed out after %d ms."):format(job_id, 50),
        mock_logger_module.levels.WARN,
        {title = "Tungsten"}
      )
      assert.spy(callback_spy).was_not.called()
    end)

    it("should use the default timeout (10000ms) if config.wolfram_timeout_ms is nil", function()
      mock_config_module.wolfram_timeout_ms = nil
      engine.evaluate_async(timeout_test_ast, false, actual_callback)
      assert.spy(mock_vim_loop_timer.start).was.called_with(mock_vim_loop_timer, 10000, 0, match.is_function())

      local job_id = _G.vim.fn.jobstart.last_returned_id
      assert.is_not_nil(job_id, "Job ID not found for default timeout test")

      current_mock_time = current_mock_time + 10000
      mock_vim_loop_timer.trigger()
      assert.spy(mock_logger_module.notify).was.called_with(
        ("Tungsten: Wolframscript job %d timed out after %d ms."):format(job_id, 10000),
        mock_logger_module.levels.WARN,
        {title = "Tungsten"}
      )
    end)

    it("should not log a timeout message if the job completes before the timeout", function()
      mock_config_module.wolfram_timeout_ms = 200
      engine.evaluate_async(timeout_test_ast, false, actual_callback)

      assert.spy(mock_vim_loop_timer.start).was.called_with(mock_vim_loop_timer, 200, 0, match.is_function())
      local job_id = _G.vim.fn.jobstart.last_returned_id
      assert.is_not_nil(job_id, "Job ID not found for no-timeout test")
      local job_options = _G.vim.fn.jobstart.fn.calls[1].vals[2]

      current_mock_time = current_mock_time + 50
      job_options.on_stdout(job_id, { "successful_output" }, 1)
      job_options.on_exit(job_id, 0, 1)

      if captured_timer_callback then captured_timer_callback() end

      local timeout_message_found = false
      for _, call in ipairs(mock_logger_module.notify.calls) do
        if type(call.vals[1]) == "string" and string.find(call.vals[1], "timed out", 1, true) then
          timeout_message_found = true
          break
        end
      end
      assert.is_false(timeout_message_found, "Timeout message should not have been logged.")
      assert.spy(callback_spy).was.called_with("successful_output", nil)
    end)

    it("should not log timeout if job is removed from active_jobs *just before* timer fires", function()
        mock_config_module.wolfram_timeout_ms = 75
        engine.evaluate_async(timeout_test_ast, false, actual_callback)

        local job_id = _G.vim.fn.jobstart.last_returned_id
        assert.is_not_nil(job_id, "Job ID was not found in active_jobs after starting")
        assert.is_not_nil(mock_state_module.active_jobs[job_id], "Job should be active after starting")

        mock_state_module.active_jobs[job_id] = nil

        current_mock_time = current_mock_time + mock_config_module.wolfram_timeout_ms
        if captured_timer_callback then captured_timer_callback() end

        local timeout_message_found = false
        for _, call_args_tbl in ipairs(mock_logger_module.notify.calls) do
          local msg = call_args_tbl.vals[1]
          if type(msg) == "string" and string.find(msg, ("Tungsten: Wolframscript job %s timed out after %d ms."):format(tostring(job_id), 75), 1, true) then
            timeout_message_found = true
            break
          end
        end
        assert.is_false(timeout_message_found, "Timeout message from timer should NOT log if job already removed from active_jobs.")
    end)
  end)


  describe("run_async(input_string, numeric, callback)", function()
    local callback_spy_run_async
    local actual_callback_run_async

    before_each(function()
      callback_spy_run_async = spy.new(function() end)
      actual_callback_run_async = function(...) callback_spy_run_async(...) end
      mock_state_module.cache = {}
      mock_state_module.active_jobs = {}
      mock_logger_module.notify:clear()
       _G.vim.fn.jobstart:clear()
      current_mock_time = 1234567890
    end)

    it("should correctly call parser.parse and then evaluate_async on success", function()
      local evaluate_async_on_engine_spy = spy.on(engine, "evaluate_async")
      engine.run_async("valid_latex", false, actual_callback_run_async)

      assert.spy(mock_parser_module.parse).was.called_with("valid_latex")
      local expected_ast = { type = "Expression", value = "parsed_valid_latex" }
      assert.spy(evaluate_async_on_engine_spy).was.called_with(expected_ast, false, actual_callback_run_async)
      evaluate_async_on_engine_spy:revert()
    end)

    it("should invoke callback with error if parser.parse fails (returns nil)", function()
      engine.run_async("error_latex", false, actual_callback_run_async)
      assert.spy(mock_parser_module.parse).was.called_with("error_latex")
      assert.spy(callback_spy_run_async).was.called_with(nil, "Parse error: nil AST")
      assert.spy(mock_logger_module.notify).was.called_with(
        "Tungsten: Parse error: nil AST",
        mock_logger_module.levels.ERROR,
        match.is_table()
      )
    end)

    it("should invoke callback with error if parser.parse throws an error (pcall context)", function()
      local erroring_parse_func = function() error("parser_panic_error_for_run_async") end
      local original_parser_parse = mock_parser_module.parse
      mock_parser_module.parse = spy.new(erroring_parse_func)

      engine.run_async("some_input_causing_panic_in_run_async", false, actual_callback_run_async)

      assert.spy(mock_parser_module.parse).was.called_with("some_input_causing_panic_in_run_async")
      assert.spy(callback_spy_run_async).was.called_with(nil, match.has_match("Parse error: .*parser_panic_error_for_run_async"))
      assert.spy(mock_logger_module.notify).was.called_with(
        match.has_match("Tungsten: Parse error: .*parser_panic_error_for_run_async"),
        mock_logger_module.levels.ERROR,
        match.is_table()
      )
      mock_parser_module.parse = original_parser_parse
    end)
  end)

  describe("Cache Management", function()
    before_each(function()
      mock_state_module.cache = {}
      mock_logger_module.notify:clear()
    end)

    it("clear_cache() should empty the cache", function()
      mock_state_module.cache["key1"] = "value1"
      mock_state_module.cache["key2"] = "value2"
      engine.clear_cache()
      assert.is_true(_G.vim.tbl_isempty(mock_state_module.cache))
      assert.spy(mock_logger_module.notify).was.called_with("Tungsten: Cache cleared.", mock_logger_module.levels.INFO, match.is_table())
    end)

    it("get_cache_size() should return the correct number of entries", function()
        mock_state_module.cache = { k1="v1", k2="v2", k3="v3"}
        local size = engine.get_cache_size()
        assert.are.equal(3, size)
        assert.spy(mock_logger_module.notify).was.called_with("Tungsten: Cache size: 3 entries.", mock_logger_module.levels.INFO, match.is_table())

        mock_logger_module.notify:clear()
        mock_state_module.cache = {}
        size = engine.get_cache_size()
        assert.are.equal(0, size)
        assert.spy(mock_logger_module.notify).was.called_with("Tungsten: Cache size: 0 entries.", mock_logger_module.levels.INFO, match.is_table())
    end)
  end)

  describe("Active Job Management", function()
    before_each(function()
      mock_state_module.active_jobs = {}
      mock_logger_module.notify:clear()
    end)

    it("view_active_jobs() should log 'No active jobs.' if active_jobs is empty", function()
      engine.view_active_jobs()
      assert.spy(mock_logger_module.notify).was.called_with("Tungsten: No active jobs.", mock_logger_module.levels.INFO, match.is_table())
    end)

    it("view_active_jobs() should log details of active jobs", function()
        mock_state_module.active_jobs = {
            [123] = { expr_key = "key_abc", bufnr = 1, code_sent = "run_this_code_abc", start_time = 1000 },
            [456] = { expr_key = "key_xyz::numeric", bufnr = 2, code_sent = "N[run_this_code_xyz]", start_time = 2000 },
        }
        engine.view_active_jobs()
        local logger_notify_spy = mock_logger_module.notify
        assert.spy(logger_notify_spy).was.called(1)
        local log_call_vals = logger_notify_spy.calls[1].vals
        local logged_string = log_call_vals[1]

        assert.is_string(logged_string)
        assert.is_not_nil(string.find(logged_string, "Active Tungsten Jobs:", 1, true), "Missing title")
        assert.is_not_nil(string.find(logged_string, "- ID: 123, Key: key_abc, Buf: 1, Code: run_this_code_abc", 1, true), "Missing job 123 details")
        assert.is_not_nil(string.find(logged_string, "- ID: 456, Key: key_xyz::numeric, Buf: 2, Code: N[run_this_code_xyz]", 1, true), "Missing job 456 details for plain match")
        assert.are.same(mock_logger_module.levels.INFO, log_call_vals[2])
        assert.are.same({ title = "Tungsten Active Jobs" }, log_call_vals[3])
    end)
  end)

  describe("Debug Logging in evaluate_async", function()
    local debug_test_ast
    local callback_spy
    local actual_callback

    before_each(function()
      debug_test_ast = { type = "Expression", value = "debug_expr_val_for_logging" }
      callback_spy = spy.new(function() end)
      actual_callback = function(...) callback_spy(...) end
      mock_config_module.debug = true
      mock_state_module.cache = {}
      mock_state_module.active_jobs = {}
      _G.vim.fn.jobstart:clear()
      mock_logger_module.notify:clear()
      current_mock_time = 1234567890
    end)


    after_each(function()
      mock_config_module.debug = false
    end)

    it("should log cache hit details in debug mode", function()
      local expr_key = "wolfram_code_for_debug_expr_val_for_logging::symbolic"
      mock_state_module.cache[expr_key] = "cached_debug_result"
      engine.evaluate_async(debug_test_ast, false, actual_callback)
      assert.spy(mock_logger_module.notify).was.called_with(
        "Tungsten Debug: Cache hit for key: " .. expr_key,
        mock_logger_module.levels.INFO,
        { title = "Tungsten Debug" }
      )
    end)

    it("should log job start details in debug mode", function()
      engine.evaluate_async(debug_test_ast, false, actual_callback)
      assert.spy(_G.vim.fn.jobstart.fn).was.called(1)
      local job_id = _G.vim.fn.jobstart.last_returned_id
      assert.is_not_nil(job_id, "Job ID not found for debug log job start")
      local expr_key = "wolfram_code_for_debug_expr_val_for_logging::symbolic"
      local code_sent = "wolfram_code_for_debug_expr_val_for_logging"
      assert.spy(mock_logger_module.notify).was.called_with(
        ("Tungsten: Started WolframScript job %d for key '%s' with code: %s"):format(job_id, expr_key, code_sent),
        mock_logger_module.levels.INFO,
        { title = "Tungsten Debug" }
      )
    end)

    it("should log job finish details in debug mode", function()
      engine.evaluate_async(debug_test_ast, false, actual_callback)
      assert.spy(_G.vim.fn.jobstart.fn).was.called(1)
      local job_id = _G.vim.fn.jobstart.last_returned_id
      local job_options = _G.vim.fn.jobstart.fn.calls[1].vals[2]

      job_options.on_exit(job_id, 0, 1)

      assert.spy(mock_logger_module.notify).was.called_with(
        "Tungsten: Job " .. job_id .. " finished and removed from active jobs.",
        mock_logger_module.levels.INFO,
        { title = "Tungsten Debug" }
      )
    end)


    it("should log cache store details in debug mode", function()
      engine.evaluate_async(debug_test_ast, false, actual_callback)
      assert.spy(_G.vim.fn.jobstart.fn).was.called(1)
      local job_id = _G.vim.fn.jobstart.last_returned_id
      local job_options = _G.vim.fn.jobstart.fn.calls[1].vals[2]


      job_options.on_stdout(job_id, { "result_to_cache" }, 1)
      job_options.on_exit(job_id, 0, 1)

      local expr_key = "wolfram_code_for_debug_expr_val_for_logging::symbolic"
      assert.spy(mock_logger_module.notify).was.called_with(
        "Tungsten: Result for key '" .. expr_key .. "' stored in cache.",
        mock_logger_module.levels.INFO,
        { title = "Tungsten Debug" }
      )
    end)


    it("should log stderr from successful job in debug mode", function()
      engine.evaluate_async(debug_test_ast, false, actual_callback)
      assert.spy(_G.vim.fn.jobstart.fn).was.called(1)
      local job_id = _G.vim.fn.jobstart.last_returned_id
      local job_options = _G.vim.fn.jobstart.fn.calls[1].vals[2]

      job_options.on_stderr(job_id, { "debug_stderr_info" }, 1)
      job_options.on_stdout(job_id, { "successful_output" }, 1)
      job_options.on_exit(job_id, 0, 1)

      assert.spy(mock_logger_module.notify).was.called_with(
         "Tungsten (Job " .. job_id .. " stderr): debug_stderr_info",
        mock_logger_module.levels.WARN,
        { title = "Tungsten Debug" }
      )
    end)

    it("should log if evaluation is already in progress for a key in debug mode", function()
      local expr_key = "wolfram_code_for_debug_expr_val_for_logging::symbolic"
      mock_state_module.active_jobs[99] = {
        expr_key = expr_key, bufnr = 1, code_sent = "wolfram_code_for_debug_expr_val_for_logging", start_time = 12345,
      }
      engine.evaluate_async(debug_test_ast, false, actual_callback)
      assert.spy(mock_logger_module.notify).was.called_with(
        ("Tungsten: Evaluation already in progress for key: '%s' (Job ID: %s)"):format(expr_key, "99"),
        mock_logger_module.levels.INFO,
        { title = "Tungsten" }
      )
    end)
  end)

  describe("get_cache_key (exposed for testing)", function()
    before_each(function()
        _G.vim.fn.jobstart:clear()
        mock_logger_module.notify:clear()
    end)
    it("should produce different keys for numeric true/false", function()
        local key_numeric = engine.get_cache_key("some_code", true)
        local key_symbolic = engine.get_cache_key("some_code", false)
        assert.are_equal("some_code::numeric", key_numeric)
        assert.are_equal("some_code::symbolic", key_symbolic)
        assert.are_not_equal(key_numeric, key_symbolic)
    end)
  end)
end)
