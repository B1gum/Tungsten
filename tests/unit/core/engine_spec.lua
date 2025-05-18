-- tests/unit/core/engine_spec.lua
-- Unit tests for the Tungsten evaluation engine.
---------------------------------------------------------------------

package.path = './lua/?.lua;' .. package.path

local spy = require('luassert.spy')
local match = require('luassert.match')
local helpers = require('tests.helpers')

describe("tungsten.core.engine", function()
  local engine
  local mock_parser_module
  local mock_wolfram_backend_module
  local mock_config_module
  local mock_state_module
  local mock_logger_module

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
        return "mock_wolfram_code"
      end),
    })

    mock_config_module = helpers.mock_utils.mock_module('tungsten.config', {
      wolfram_path = "mock_wolframscript",
      numeric_mode = false,
      debug = false,
      cache_enabled = true,
      domains = { "arithmetic" },
    })

    mock_state_module = helpers.mock_utils.mock_module('tungsten.state', {
      cache = {},
      active_jobs = {},
    })

    local logger_spec_base = {
      levels = { ERROR = 1, WARN = 2, INFO = 3, DEBUG = 4 }
    }
    mock_logger_module = helpers.mock_utils.mock_module('tungsten.util.logger', logger_spec_base)
    mock_logger_module.notify = spy.new(function() end)

    helpers.vim_test_env.setup({
        deep_equal = function(a, b)
            return require('luassert.match').compare(a, b)
        end
    })
    engine = require("tungsten.core.engine")
  end)

  after_each(function()
    helpers.vim_test_env.teardown()
    helpers.mock_utils.reset_modules(modules_to_reset)
  end)

  describe("evaluate_async(ast, numeric, callback)", function()
    local sample_ast
    local callback_spy
    local actual_callback

    before_each(function()
      sample_ast = { type = "Expression", value = "some_expression" }
      callback_spy = spy.new(function() end)
      actual_callback = function(...) callback_spy(...) end
      mock_config_module.cache_enabled = true
      mock_state_module.cache = {}
      mock_state_module.active_jobs = {}
      if _G.vim.fn.jobstart.is_spy and _G.vim.fn.jobstart.reset then _G.vim.fn.jobstart:reset() end
      if package.loaded['tungsten.util.logger'] and package.loaded['tungsten.util.logger'].notify and package.loaded['tungsten.util.logger'].notify.is_spy then
          package.loaded['tungsten.util.logger'].notify:reset()
      end
    end)

    it("should successfully evaluate symbolically", function()
      engine.evaluate_async(sample_ast, false, actual_callback)
      assert.spy(mock_wolfram_backend_module.to_string).was.called_with(sample_ast)
      assert.spy(_G.vim.fn.jobstart).was.called(1)
      local jobstart_args = _G.vim.fn.jobstart.calls[1].vals[1]
      assert.are.same({ "mock_wolframscript", "-code", "wolfram_code_for_some_expression" }, jobstart_args)
      local job_options = _G.vim.fn.jobstart.calls[1].vals[2]
      job_options.on_stdout(1, { "symbolic_result" }, 1)
      job_options.on_exit(1, 0, 1)
      assert.spy(callback_spy).was.called_with("symbolic_result", nil)
    end)

    it("should successfully evaluate numerically, wrapping code with N[]", function()
      engine.evaluate_async(sample_ast, true, actual_callback)
      assert.spy(mock_wolfram_backend_module.to_string).was.called_with(sample_ast)
      assert.spy(_G.vim.fn.jobstart).was.called(1)
      local jobstart_args = _G.vim.fn.jobstart.calls[1].vals[1]
      assert.are.same({ "mock_wolframscript", "-code", "N[wolfram_code_for_some_expression]" }, jobstart_args)
      local job_options = _G.vim.fn.jobstart.calls[1].vals[2]
      job_options.on_stdout(1, { "numeric_result" }, 1)
      job_options.on_exit(1, 0, 1)
      assert.spy(callback_spy).was.called_with("numeric_result", nil)
    end)

    it("should use global config.numeric_mode if 'numeric' param is false but global is true", function()
      mock_config_module.numeric_mode = true
      engine.evaluate_async(sample_ast, false, actual_callback)
      assert.spy(_G.vim.fn.jobstart).was.called(1)
      local jobstart_args = _G.vim.fn.jobstart.calls[1].vals[1]
      assert.are.same({ "mock_wolframscript", "-code", "N[wolfram_code_for_some_expression]" }, jobstart_args)
    end)

    it("should return cached result immediately if cache is enabled and item exists", function()
      mock_config_module.cache_enabled = true
      local expr_key = "wolfram_code_for_some_expression::symbolic"
      mock_state_module.cache[expr_key] = "cached_symbolic_result"
      engine.evaluate_async(sample_ast, false, actual_callback)
      assert.spy(callback_spy).was.called_with("cached_symbolic_result", nil)
      assert.spy(_G.vim.fn.jobstart).was_not.called()
      assert.spy(package.loaded['tungsten.util.logger'].notify).was.called_with("Tungsten: Result from cache.", mock_logger_module.levels.INFO, match.is_table())
    end)

    it("should start a job and cache the result if cache is enabled and item does not exist (cache miss)", function()
      mock_config_module.cache_enabled = true
      local expr_key = "wolfram_code_for_some_expression::symbolic"
      engine.evaluate_async(sample_ast, false, actual_callback)
      assert.spy(_G.vim.fn.jobstart).was.called(1)
      local job_options = _G.vim.fn.jobstart.calls[1].vals[2]
      job_options.on_stdout(1, { "new_symbolic_result" }, 1)
      job_options.on_exit(1, 0, 1)
      assert.spy(callback_spy).was.called_with("new_symbolic_result", nil)
      assert.are.equal("new_symbolic_result", mock_state_module.cache[expr_key])
    end)

    it("should always start a job and not use/store in cache if cache is disabled", function()
      mock_config_module.cache_enabled = false
      local expr_key = "wolfram_code_for_some_expression::symbolic"
      mock_state_module.cache[expr_key] = "cached_symbolic_result_but_disabled"
      engine.evaluate_async(sample_ast, false, actual_callback)
      assert.spy(_G.vim.fn.jobstart).was.called(1)
      local job_options = _G.vim.fn.jobstart.calls[1].vals[2]
      job_options.on_stdout(1, { "fresh_result_no_cache" }, 1)
      job_options.on_exit(1, 0, 1)
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
      assert.spy(_G.vim.fn.jobstart).was_not.called()
      assert.spy(package.loaded['tungsten.util.logger'].notify).was.called_with(
        match.has_match("Tungsten: Error converting AST to Wolfram code:"),
        mock_logger_module.levels.ERROR,
        match.is_table()
      )
    end)

    it("should invoke callback with error if vim.fn.jobstart returns 0", function()
      _G.vim.fn.jobstart = spy.new(function() return 0 end)
      engine.evaluate_async(sample_ast, false, actual_callback)
      assert.spy(callback_spy).was.called_with(nil, "Failed to start WolframScript job. (Reason: Invalid arguments to jobstart)")
      assert.spy(package.loaded['tungsten.util.logger'].notify).was.called_with(
        "Tungsten: Failed to start WolframScript job. (Reason: Invalid arguments to jobstart)",
        mock_logger_module.levels.ERROR,
        match.is_table()
      )
    end)

    it("should invoke callback with error if vim.fn.jobstart returns -1", function()
      _G.vim.fn.jobstart = spy.new(function() return -1 end)
      engine.evaluate_async(sample_ast, false, actual_callback)
      local expected_err_msg = "Failed to start WolframScript job. (Reason: Command 'mock_wolframscript' not found - is wolframscript in your PATH?)"
      assert.spy(callback_spy).was.called_with(nil, expected_err_msg)
      assert.spy(package.loaded['tungsten.util.logger'].notify).was.called_with(
        "Tungsten: " .. expected_err_msg,
        mock_logger_module.levels.ERROR,
        match.is_table()
      )
    end)

    it("should invoke callback with error if WolframScript exits with non-zero code and stderr output", function()
      engine.evaluate_async(sample_ast, false, actual_callback)
      local job_options = _G.vim.fn.jobstart.calls[1].vals[2]
      job_options.on_stderr(1, { "wolfram_error_output" }, 1)
      job_options.on_exit(1, 1, 1)
      assert.spy(callback_spy).was.called_with(nil, match.has_match("WolframScript %(Job 1%) exited with code 1\nStderr: wolfram_error_output"))
      assert.spy(package.loaded['tungsten.util.logger'].notify).was.called_with(
        match.has_match("Tungsten: WolframScript %(Job 1%) exited with code 1\nStderr: wolfram_error_output"),
        mock_logger_module.levels.ERROR,
        match.is_table()
      )
    end)

     it("should invoke callback with error if WolframScript exits with non-zero code and stdout output (no stderr)", function()
      engine.evaluate_async(sample_ast, false, actual_callback)
      local job_options = _G.vim.fn.jobstart.calls[1].vals[2]
      job_options.on_stdout(1, { "some_stdout_content_on_error" }, 1)
      job_options.on_exit(1, 127, 1)
      assert.spy(callback_spy).was.called_with(nil, match.has_match("WolframScript %(Job 1%) exited with code 127\nStdout %(potentially error%): some_stdout_content_on_error"))
       assert.spy(package.loaded['tungsten.util.logger'].notify).was.called_with(
        match.has_match("Tungsten: WolframScript %(Job 1%) exited with code 127\nStdout %(potentially error%): some_stdout_content_on_error"),
        mock_logger_module.levels.ERROR,
        match.is_table()
      )
    end)

    it("should log a notification and not start a new job if a job for the same expression is already in progress", function()
      local expr_key = "wolfram_code_for_some_expression::symbolic"
      mock_state_module.active_jobs[99] = {
        expr_key = expr_key, bufnr = 1, code_sent = "wolfram_code_for_some_expression", start_time = 12345,
      }
      engine.evaluate_async(sample_ast, false, actual_callback)
      assert.spy(package.loaded['tungsten.util.logger'].notify).was.called_with("Tungsten: Evaluation already in progress for this expression.", mock_logger_module.levels.INFO, match.is_table())
      assert.spy(_G.vim.fn.jobstart).was_not.called()
      assert.spy(callback_spy).was_not.called()
    end)

    it("should add job to active_jobs on start and remove on exit", function()
      assert.is_true(_G.vim.tbl_isempty(mock_state_module.active_jobs))
      engine.evaluate_async(sample_ast, false, actual_callback)
      local expected_job_id = 1
      assert.is_not_nil(mock_state_module.active_jobs[expected_job_id])
      assert.are.equal("wolfram_code_for_some_expression::symbolic", mock_state_module.active_jobs[expected_job_id].expr_key)
      assert.are.equal(1, mock_state_module.active_jobs[expected_job_id].bufnr)
      assert.are.equal(1234567890, mock_state_module.active_jobs[expected_job_id].start_time)
      local job_options = _G.vim.fn.jobstart.calls[1].vals[2]
      job_options.on_exit(expected_job_id, 0, 1)
      assert.is_nil(mock_state_module.active_jobs[expected_job_id])
    end)
  end)

  describe("run_async(input_string, numeric, callback)", function()
    local callback_spy
    local actual_callback
    local original_pcall_for_run_async

    before_each(function()
      callback_spy = spy.new(function() end)
      actual_callback = function(...) callback_spy(...) end
      mock_state_module.cache = {}
      mock_state_module.active_jobs = {}
      original_pcall_for_run_async = _G.pcall
      if package.loaded['tungsten.util.logger'] and package.loaded['tungsten.util.logger'].notify and package.loaded['tungsten.util.logger'].notify.is_spy then
          package.loaded['tungsten.util.logger'].notify:reset()
      end
    end)

    after_each(function()
      _G.pcall = original_pcall_for_run_async
    end)

    it("should correctly call parser.parse and then evaluate_async on success", function()
      local evaluate_async_spy = spy.on(engine, "evaluate_async")
      engine.run_async("valid_latex", false, actual_callback)
      assert.spy(mock_parser_module.parse).was.called_with("valid_latex")
      local expected_ast = { type = "Expression", value = "parsed_valid_latex" }
      assert.spy(evaluate_async_spy).was.called_with(expected_ast, false, actual_callback)
      evaluate_async_spy:revert()
    end)

    it("should invoke callback with error if parser.parse fails (returns nil)", function()
      engine.run_async("error_latex", false, actual_callback)
      assert.spy(mock_parser_module.parse).was.called_with("error_latex")
      assert.spy(callback_spy).was.called_with(nil, "Parse error: nil AST")
      assert.spy(package.loaded['tungsten.util.logger'].notify).was.called_with(
        "Tungsten: Parse error: nil AST",
        mock_logger_module.levels.ERROR,
        match.is_table()
      )
    end)

    it("should invoke callback with error if parser.parse throws an error (pcall context)", function()
      local original_pcall_func = _G.pcall
      local test_specific_pcall_spy = spy.new(function(f, ...)
        return original_pcall_func(f, ...)
      end)
      _G.pcall = test_specific_pcall_spy

      local erroring_parse_spy = spy.new(function() error("parser_panic_error_for_run_async") end)
      helpers.mock_utils.mock_module('tungsten.core.parser', {
        parse = erroring_parse_spy
      })

      helpers.mock_utils.reset_modules({'tungsten.core.engine'})
      engine = require("tungsten.core.engine")

      engine.run_async("some_input_causing_panic_in_run_async", false, actual_callback)

      assert.spy(test_specific_pcall_spy).was.called()
      local pcall_call_args = test_specific_pcall_spy.calls[1].vals
      assert.is_not_nil(pcall_call_args, "pcall spy was not called or call not recorded")
      if pcall_call_args then
          assert.are.same(erroring_parse_spy, pcall_call_args[1], "pcall was not called with the expected erroring_parse_spy as its first argument.")
          assert.are.same("some_input_causing_panic_in_run_async", pcall_call_args[2], "pcall was not called with the expected input string.")
      end

      assert.spy(callback_spy).was.called_with(nil, match.has_match("Parse error: .*parser_panic_error_for_run_async"))
      assert.spy(package.loaded['tungsten.util.logger'].notify).was.called_with(
        match.has_match("Tungsten: Parse error: .*parser_panic_error_for_run_async"),
        mock_logger_module.levels.ERROR,
        match.is_table()
      )
    end)
  end)

  describe("Cache Management", function()
    before_each(function()
      mock_state_module.cache = {}
    end)

    it("clear_cache() should empty the cache", function()
      mock_state_module.cache["key1"] = "value1"
      mock_state_module.cache["key2"] = "value2"
      engine.clear_cache()
      assert.is_true(_G.vim.tbl_isempty(mock_state_module.cache))
      assert.spy(package.loaded['tungsten.util.logger'].notify).was.called_with("Tungsten: Cache cleared.", mock_logger_module.levels.INFO, match.is_table())
    end)

  end)

  describe("Active Job Management", function()
    before_each(function()
      mock_state_module.active_jobs = {}
    end)

    it("view_active_jobs() should log 'No active jobs.' if active_jobs is empty", function()
      engine.view_active_jobs()
      assert.spy(package.loaded['tungsten.util.logger'].notify).was.called_with("Tungsten: No active jobs.", mock_logger_module.levels.INFO, match.is_table())
    end)

    it("view_active_jobs() should log details of active jobs", function()
        mock_state_module.active_jobs = {
            [123] = { expr_key = "key_abc", bufnr = 1, code_sent = "run_this_code_abc", start_time = 1000 },
            [456] = { expr_key = "key_xyz::numeric", bufnr = 2, code_sent = "N[run_this_code_xyz]", start_time = 2000 },
        }
        engine.view_active_jobs()
        local logger_notify_spy = package.loaded['tungsten.util.logger'].notify
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

  describe("Active Job Management", function()
    before_each(function()
      mock_state_module.active_jobs = {}
    end)

    it("view_active_jobs() should log 'No active jobs.' if active_jobs is empty", function()
      engine.view_active_jobs()
      assert.spy(package.loaded['tungsten.util.logger'].notify).was.called_with("Tungsten: No active jobs.", mock_logger_module.levels.INFO, match.is_table())
    end)

    it("view_active_jobs() should log details of active jobs", function()
        mock_state_module.active_jobs = {
            [123] = { expr_key = "key_abc", bufnr = 1, code_sent = "run_this_code_abc", start_time = 1000 },
            [456] = { expr_key = "key_xyz::numeric", bufnr = 2, code_sent = "N[run_this_code_xyz]", start_time = 2000 },
        }
        engine.view_active_jobs()
        local logger_notify_spy = package.loaded['tungsten.util.logger'].notify
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
    local sample_ast
    local callback_spy
    local actual_callback

    before_each(function()
      sample_ast = { type = "Expression", value = "debug_expr" }
      callback_spy = spy.new(function() end)
      actual_callback = function(...) callback_spy(...) end
      mock_config_module.debug = true
      mock_state_module.cache = {}
      mock_state_module.active_jobs = {}
      if _G.vim.fn.jobstart.is_spy and _G.vim.fn.jobstart.reset then _G.vim.fn.jobstart:reset() end
    end)

    after_each(function()
      mock_config_module.debug = false
    end)

    it("should log cache hit details in debug mode", function()
      local expr_key = "wolfram_code_for_debug_expr::symbolic"
      mock_state_module.cache[expr_key] = "cached_debug_result"
      engine.evaluate_async(sample_ast, false, actual_callback)
      assert.spy(package.loaded['tungsten.util.logger'].notify).was.called_with(
        "Tungsten Debug: Cache hit for key: " .. expr_key,
        mock_logger_module.levels.INFO,
        { title = "Tungsten Debug" }
      )
    end)

    it("should log job start details in debug mode", function()
      engine.evaluate_async(sample_ast, false, actual_callback)
      local expected_job_id = 1
      local expr_key = "wolfram_code_for_debug_expr::symbolic"
      local code_sent = "wolfram_code_for_debug_expr"
      assert.spy(package.loaded['tungsten.util.logger'].notify).was.called_with(
        ("Tungsten: Started WolframScript job %d for key '%s' with code: %s"):format(expected_job_id, expr_key, code_sent),
        mock_logger_module.levels.INFO,
        { title = "Tungsten Debug" }
      )
    end)

    it("should log job finish details in debug mode", function()
      engine.evaluate_async(sample_ast, false, actual_callback)
      local expected_job_id = 1
      local job_options = _G.vim.fn.jobstart.calls[1].vals[2]

      local job_finish_message = "Tungsten: Job " .. expected_job_id .. " finished and removed from active jobs."
      local job_finish_level = mock_logger_module.levels.INFO
      local job_finish_opts = { title = "Tungsten Debug" }

      job_options.on_exit(expected_job_id, 0, 1)

      assert.spy(package.loaded['tungsten.util.logger'].notify).was.called_with(job_finish_message, job_finish_level, job_finish_opts)
    end)


    it("should log cache store details in debug mode", function()
      engine.evaluate_async(sample_ast, false, actual_callback)
      local job_options = _G.vim.fn.jobstart.calls[1].vals[2]

      job_options.on_stdout(1, { "result_to_cache" }, 1)
      job_options.on_exit(1, 0, 1)

      local expr_key = "wolfram_code_for_debug_expr::symbolic"
      local cache_store_message = "Tungsten: Result for key '" .. expr_key .. "' stored in cache."
      local cache_store_level = mock_logger_module.levels.INFO
      local cache_store_opts = { title = "Tungsten Debug" }

      assert.spy(package.loaded['tungsten.util.logger'].notify).was.called_with(cache_store_message, cache_store_level, cache_store_opts)
    end)


    it("should log stderr from successful job in debug mode", function()
      engine.evaluate_async(sample_ast, false, actual_callback)
      local expected_job_id = 1
      local job_options = _G.vim.fn.jobstart.calls[1].vals[2]

      local stderr_message = "Tungsten (Job " .. expected_job_id .. " stderr): debug_stderr_info"
      local stderr_level = mock_logger_module.levels.WARN
      local stderr_opts = { title = "Tungsten Debug" }

      job_options.on_stderr(expected_job_id, { "debug_stderr_info" }, 1)
      job_options.on_stdout(expected_job_id, { "successful_output" }, 1)
      job_options.on_exit(expected_job_id, 0, 1)

      assert.spy(package.loaded['tungsten.util.logger'].notify).was.called_with(stderr_message, stderr_level, stderr_opts)
    end)

    it("should log if evaluation is already in progress for a key in debug mode", function()
      local expr_key = "wolfram_code_for_debug_expr::symbolic"
      mock_state_module.active_jobs[99] = {
        expr_key = expr_key, bufnr = 1, code_sent = "wolfram_code_for_debug_expr", start_time = 12345,
      }
      engine.evaluate_async(sample_ast, false, actual_callback)
      assert.spy(package.loaded['tungsten.util.logger'].notify).was.called_with(
        ("Tungsten: Evaluation already in progress for key: '%s' (Job ID: %s)"):format(expr_key, "99"),
        mock_logger_module.levels.INFO,
        { title = "Tungsten" }
      )
    end)
  end)
end)
