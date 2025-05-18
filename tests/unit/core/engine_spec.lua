-- tests/unit/core/engine_spec.lua
-- Unit tests for the Tungsten evaluation engine.
---------------------------------------------------------------------

package.path = './lua/?.lua;' .. package.path

local spy = require('luassert.spy')
local match = require('luassert.match')

describe("tungsten.core.engine", function()
  local engine
  local mock_parser_module
  local mock_wolfram_backend_module
  local mock_config_module
  local mock_state_module
  local mock_logger_module
  local mock_vim_fn
  local mock_vim_api
  local mock_vim_loop

  local original_vim
  local original_pcall

  before_each(function()
    package.loaded['tungsten.core.engine'] = nil
    package.loaded['tungsten.core.parser'] = nil
    package.loaded['tungsten.backends.wolfram'] = nil
    package.loaded['tungsten.config'] = nil
    package.loaded['tungsten.state'] = nil
    package.loaded['tungsten.util.logger'] = nil

    original_vim = _G.vim
    mock_vim_fn = {
      jobstart = spy.new(function() return 1 end),
    }
    mock_vim_api = {
      nvim_get_current_buf = spy.new(function() return 1 end),
    }
    mock_vim_loop = {
      now = spy.new(function() return 1234567890 end),
    }
    _G.vim = {
      fn = mock_vim_fn,
      api = mock_vim_api,
      loop = mock_vim_loop,
      tbl_isempty = function(tbl)
        return next(tbl) == nil
      end,
    }

    mock_parser_module = {
      parse = spy.new(function(input_str)
        if input_str == "valid_latex" then
          return { type = "Expression", value = "parsed_valid_latex" }
        elseif input_str == "error_latex" then
          return nil
        else
          return { type = "Expression", value = "parsed_" .. input_str }
        end
      end),
    }
    package.loaded['tungsten.core.parser'] = mock_parser_module

    mock_wolfram_backend_module = {
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
    }
    package.loaded['tungsten.backends.wolfram'] = mock_wolfram_backend_module

    mock_config_module = {
      wolfram_path = "mock_wolframscript",
      numeric_mode = false,
      debug = false,
      cache_enabled = true,
      domains = { "arithmetic" },
    }
    package.loaded['tungsten.config'] = mock_config_module

    mock_state_module = {
      cache = {},
      active_jobs = {},
    }
    package.loaded['tungsten.state'] = mock_state_module

    mock_logger_module = {
      notify = spy.new(function() end),
      levels = { ERROR = 1, WARN = 2, INFO = 3, DEBUG = 4 },
    }
    package.loaded['tungsten.util.logger'] = mock_logger_module

    original_pcall = _G.pcall

    engine = require("tungsten.core.engine")
  end)

  after_each(function()
    _G.vim = original_vim
    _G.pcall = original_pcall
    package.loaded['tungsten.core.engine'] = nil
    package.loaded['tungsten.core.parser'] = nil
    package.loaded['tungsten.backends.wolfram'] = nil
    package.loaded['tungsten.config'] = nil
    package.loaded['tungsten.state'] = nil
    package.loaded['tungsten.util.logger'] = nil
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
    end)

    it("should successfully evaluate symbolically", function()
      engine.evaluate_async(sample_ast, false, actual_callback)
      assert.spy(mock_wolfram_backend_module.to_string).was.called_with(sample_ast)
      assert.spy(mock_vim_fn.jobstart).was.called(1)
      local jobstart_args = mock_vim_fn.jobstart.calls[1].vals[1]
      assert.are.same({ "mock_wolframscript", "-code", "wolfram_code_for_some_expression" }, jobstart_args)
      local job_options = mock_vim_fn.jobstart.calls[1].vals[2]
      job_options.on_stdout(1, { "symbolic_result" }, 1)
      job_options.on_exit(1, 0, 1)
      assert.spy(callback_spy).was.called_with("symbolic_result", nil)
    end)

    it("should successfully evaluate numerically, wrapping code with N[]", function()
      engine.evaluate_async(sample_ast, true, actual_callback)
      assert.spy(mock_wolfram_backend_module.to_string).was.called_with(sample_ast)
      assert.spy(mock_vim_fn.jobstart).was.called(1)
      local jobstart_args = mock_vim_fn.jobstart.calls[1].vals[1]
      assert.are.same({ "mock_wolframscript", "-code", "N[wolfram_code_for_some_expression]" }, jobstart_args)
      local job_options = mock_vim_fn.jobstart.calls[1].vals[2]
      job_options.on_stdout(1, { "numeric_result" }, 1)
      job_options.on_exit(1, 0, 1)
      assert.spy(callback_spy).was.called_with("numeric_result", nil)
    end)

    it("should use global config.numeric_mode if 'numeric' param is false but global is true", function()
      mock_config_module.numeric_mode = true
      engine.evaluate_async(sample_ast, false, actual_callback)
      assert.spy(mock_vim_fn.jobstart).was.called(1)
      local jobstart_args = mock_vim_fn.jobstart.calls[1].vals[1]
      assert.are.same({ "mock_wolframscript", "-code", "N[wolfram_code_for_some_expression]" }, jobstart_args)
    end)

    it("should return cached result immediately if cache is enabled and item exists", function()
      mock_config_module.cache_enabled = true
      local expr_key = "wolfram_code_for_some_expression::symbolic"
      mock_state_module.cache[expr_key] = "cached_symbolic_result"
      engine.evaluate_async(sample_ast, false, actual_callback)
      assert.spy(callback_spy).was.called_with("cached_symbolic_result", nil)
      assert.spy(mock_vim_fn.jobstart).was_not.called()
      assert.spy(mock_logger_module.notify).was.called_with("Tungsten: Result from cache.", mock_logger_module.levels.INFO, match.is_table())
    end)

    it("should start a job and cache the result if cache is enabled and item does not exist (cache miss)", function()
      mock_config_module.cache_enabled = true
      local expr_key = "wolfram_code_for_some_expression::symbolic"
      engine.evaluate_async(sample_ast, false, actual_callback)
      assert.spy(mock_vim_fn.jobstart).was.called(1)
      local job_options = mock_vim_fn.jobstart.calls[1].vals[2]
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
      assert.spy(mock_vim_fn.jobstart).was.called(1)
      local job_options = mock_vim_fn.jobstart.calls[1].vals[2]
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
      assert.spy(mock_vim_fn.jobstart).was_not.called()
      assert.spy(mock_logger_module.notify).was.called_with(
        match.has_match("Tungsten: Error converting AST to Wolfram code:"),
        mock_logger_module.levels.ERROR,
        match.is_table()
      )
    end)

    it("should invoke callback with error if vim.fn.jobstart returns 0", function()
      mock_vim_fn.jobstart = spy.new(function() return 0 end)
      engine.evaluate_async(sample_ast, false, actual_callback)
      assert.spy(callback_spy).was.called_with(nil, "Failed to start WolframScript job. (Reason: Invalid arguments to jobstart)")
      assert.spy(mock_logger_module.notify).was.called_with(
        "Tungsten: Failed to start WolframScript job. (Reason: Invalid arguments to jobstart)",
        mock_logger_module.levels.ERROR,
        match.is_table()
      )
    end)

    it("should invoke callback with error if vim.fn.jobstart returns -1", function()
      mock_vim_fn.jobstart = spy.new(function() return -1 end)
      engine.evaluate_async(sample_ast, false, actual_callback)
      local expected_err_msg = "Failed to start WolframScript job. (Reason: Command 'mock_wolframscript' not found - is wolframscript in your PATH?)"
      assert.spy(callback_spy).was.called_with(nil, expected_err_msg)
      assert.spy(mock_logger_module.notify).was.called_with(
        "Tungsten: " .. expected_err_msg,
        mock_logger_module.levels.ERROR,
        match.is_table()
      )
    end)

    it("should invoke callback with error if WolframScript exits with non-zero code and stderr output", function()
      engine.evaluate_async(sample_ast, false, actual_callback)
      local job_options = mock_vim_fn.jobstart.calls[1].vals[2]
      job_options.on_stderr(1, { "wolfram_error_output" }, 1)
      job_options.on_exit(1, 1, 1)
      assert.spy(callback_spy).was.called_with(nil, match.has_match("WolframScript %(Job 1%) exited with code 1\nStderr: wolfram_error_output"))
      assert.spy(mock_logger_module.notify).was.called_with(
        match.has_match("Tungsten: WolframScript %(Job 1%) exited with code 1\nStderr: wolfram_error_output"),
        mock_logger_module.levels.ERROR,
        match.is_table()
      )
    end)

     it("should invoke callback with error if WolframScript exits with non-zero code and stdout output (no stderr)", function()
      engine.evaluate_async(sample_ast, false, actual_callback)
      local job_options = mock_vim_fn.jobstart.calls[1].vals[2]
      job_options.on_stdout(1, { "some_stdout_content_on_error" }, 1)
      job_options.on_exit(1, 127, 1)
      assert.spy(callback_spy).was.called_with(nil, match.has_match("WolframScript %(Job 1%) exited with code 127\nStdout %(potentially error%): some_stdout_content_on_error"))
       assert.spy(mock_logger_module.notify).was.called_with(
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
      assert.spy(mock_logger_module.notify).was.called_with("Tungsten: Evaluation already in progress for this expression.", mock_logger_module.levels.INFO, match.is_table())
      assert.spy(mock_vim_fn.jobstart).was_not.called()
      assert.spy(callback_spy).was_not.called()
    end)

    it("should add job to active_jobs on start and remove on exit", function()
      assert.is_true(vim.tbl_isempty(mock_state_module.active_jobs))
      engine.evaluate_async(sample_ast, false, actual_callback)
      local expected_job_id = 1
      assert.is_not_nil(mock_state_module.active_jobs[expected_job_id])
      assert.are.equal("wolfram_code_for_some_expression::symbolic", mock_state_module.active_jobs[expected_job_id].expr_key)
      assert.are.equal(1, mock_state_module.active_jobs[expected_job_id].bufnr)
      assert.are.equal(1234567890, mock_state_module.active_jobs[expected_job_id].start_time)
      local job_options = mock_vim_fn.jobstart.calls[1].vals[2]
      job_options.on_exit(expected_job_id, 0, 1)
      assert.is_nil(mock_state_module.active_jobs[expected_job_id])
    end)
  end)

  describe("run_async(input_string, numeric, callback)", function()
    local callback_spy
    local actual_callback

    before_each(function()
      callback_spy = spy.new(function() end)
      actual_callback = function(...) callback_spy(...) end
      mock_state_module.cache = {}
      mock_state_module.active_jobs = {}
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
      assert.spy(mock_logger_module.notify).was.called_with(
        "Tungsten: Parse error: nil AST",
        mock_logger_module.levels.ERROR,
        match.is_table()
      )
    end)

    it("should invoke callback with error if parser.parse throws an error (pcall context)", function()
      mock_parser_module.parse = spy.new(function() error("parser_panic_error") end)

      local test_specific_pcall_spy = spy.new(function(f, ...)
        return original_pcall(f, ...)
      end)
      _G.pcall = test_specific_pcall_spy

      package.loaded['tungsten.core.engine'] = nil
      local current_engine_instance = require("tungsten.core.engine")

      current_engine_instance.run_async("some_input_causing_panic", false, actual_callback)

      assert.spy(test_specific_pcall_spy).was.called()
      assert.are.same(mock_parser_module.parse, test_specific_pcall_spy.calls[1].vals[1])
      assert.spy(callback_spy).was.called_with(nil, match.has_match("Parse error: tests/unit/core/engine_spec.lua:319: parser_panic_error"))

      assert.spy(mock_logger_module.notify).was.called_with(
        "Tungsten: Parse error: tests/unit/core/engine_spec.lua:319: parser_panic_error",
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
      assert.is_true(vim.tbl_isempty(mock_state_module.cache))
      assert.spy(mock_logger_module.notify).was.called_with("Tungsten: Cache cleared.", mock_logger_module.levels.INFO, match.is_table())
    end)

    it("get_cache_size() should return the correct number of items in the cache", function()
      engine.get_cache_size()
      assert.spy(mock_logger_module.notify).was.called_with("Tungsten: Cache size: 0 entries.", mock_logger_module.levels.INFO, match.is_table())
      if mock_logger_module.notify.reset then
          mock_logger_module.notify:reset()
      else
          mock_logger_module.notify = spy.new(function() end)
      end

      mock_state_module.cache["key1"] = "value1"
      engine.get_cache_size()
      assert.spy(mock_logger_module.notify).was.called_with("Tungsten: Cache size: 1 entries.", mock_logger_module.levels.INFO, match.is_table())
      if mock_logger_module.notify.reset then
          mock_logger_module.notify:reset()
      else
          mock_logger_module.notify = spy.new(function() end)
      end

      mock_state_module.cache["key2"] = "value2"
      mock_state_module.cache["key3"] = "value3"
      engine.get_cache_size()
      assert.spy(mock_logger_module.notify).was.called_with("Tungsten: Cache size: 3 entries.", mock_logger_module.levels.INFO, match.is_table())
    end)
  end)

  describe("Active Job Management", function()
    before_each(function()
      mock_state_module.active_jobs = {}
      mock_logger_module.notify = spy.new(function() end)
    end)

    it("view_active_jobs() should log 'No active jobs.' if active_jobs is empty", function()
      engine.view_active_jobs()
      assert.spy(mock_logger_module.notify).was.called_with("Tungsten: No active jobs.", mock_logger_module.levels.INFO, match.is_table())
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
    end)

    after_each(function()
      mock_config_module.debug = false
    end)

    it("should log cache hit details in debug mode", function()
      local expr_key = "wolfram_code_for_debug_expr::symbolic"
      mock_state_module.cache[expr_key] = "cached_debug_result"
      engine.evaluate_async(sample_ast, false, actual_callback)
      assert.spy(mock_logger_module.notify).was.called_with(
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
      assert.spy(mock_logger_module.notify).was.called_with(
        ("Tungsten: Started WolframScript job %d for key '%s' with code: %s"):format(expected_job_id, expr_key, code_sent),
        mock_logger_module.levels.INFO,
        { title = "Tungsten Debug" }
      )
    end)

    it("should log job finish details in debug mode", function()
      engine.evaluate_async(sample_ast, false, actual_callback)
      local expected_job_id = 1
      local job_options = mock_vim_fn.jobstart.calls[1].vals[2]
      job_options.on_exit(expected_job_id, 0, 1)
      assert.spy(mock_logger_module.notify).was.called_with(
        "Tungsten: Job " .. expected_job_id .. " finished and removed from active jobs.",
        mock_logger_module.levels.INFO,
        { title = "Tungsten Debug" }
      )
    end)

    it("should log cache store details in debug mode", function()
      engine.evaluate_async(sample_ast, false, actual_callback)
      local job_options = mock_vim_fn.jobstart.calls[1].vals[2]
      job_options.on_stdout(1, { "result_to_cache" }, 1)
      job_options.on_exit(1, 0, 1)
      local expr_key = "wolfram_code_for_debug_expr::symbolic"
      assert.spy(mock_logger_module.notify).was.called_with(
        "Tungsten: Result for key '" .. expr_key .. "' stored in cache.",
        mock_logger_module.levels.INFO,
        { title = "Tungsten Debug" }
      )
    end)

    it("should log stderr from successful job in debug mode", function()
        engine.evaluate_async(sample_ast, false, actual_callback)
        local expected_job_id = 1
        local job_options = mock_vim_fn.jobstart.calls[1].vals[2]
        job_options.on_stderr(expected_job_id, { "debug_stderr_info" }, 1)
        job_options.on_stdout(expected_job_id, { "successful_output" }, 1)
        job_options.on_exit(expected_job_id, 0, 1)
        assert.spy(mock_logger_module.notify).was.called_with(
            "Tungsten (Job " .. expected_job_id .. " stderr): debug_stderr_info",
            mock_logger_module.levels.WARN,
            { title = "Tungsten Debug" }
        )
    end)

    it("should log if evaluation is already in progress for a key in debug mode", function()
      local expr_key = "wolfram_code_for_debug_expr::symbolic"
      mock_state_module.active_jobs[99] = {
        expr_key = expr_key, bufnr = 1, code_sent = "wolfram_code_for_debug_expr", start_time = 12345,
      }
      engine.evaluate_async(sample_ast, false, actual_callback)
      assert.spy(mock_logger_module.notify).was.called_with(
        ("Tungsten: Evaluation already in progress for key: '%s' (Job ID: %s)"):format(expr_key, "99"),
        mock_logger_module.levels.INFO,
        { title = "Tungsten" }
      )
    end)
  end)
end)

