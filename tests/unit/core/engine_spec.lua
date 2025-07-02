-- tests/unit/core/engine_spec.lua
-- Unit tests for the core evaluation engine of Tungsten.
----------------------------------------------------------

package.path = './lua/?.lua;./lua/?/init.lua;' .. package.path

local spy = require 'luassert.spy'
local match = require 'luassert.match'
local vim_test_env = require 'tests.helpers.vim_test_env'

describe("tungsten.core.engine", function()
  local engine

  local mock_wolfram_codegen
  local mock_config
  local mock_state
  local mock_async
  local mock_logger

  local wolfram_to_string_spy
  local async_run_job_spy
  local logger_notify_spy

  local original_require
  local original_vim_schedule

  local modules_to_clear_from_cache = {
    'tungsten.core.engine',
    'tungsten.backends.wolfram',
    'tungsten.config',
    'tungsten.state',
    'tungsten.util.async',
    'tungsten.util.logger',
  }

  local function clear_modules_from_cache()
    for _, name in ipairs(modules_to_clear_from_cache) do
      package.loaded[name] = nil
    end
  end

  local function ast_node(id)
    return { type = "expression", id = id or "test_ast" }
  end

  before_each(function()
    mock_wolfram_codegen = { to_string = function() end }
    mock_config = {
      wolfram_path = "mock_wolframscript",
      numeric_mode = false,
      debug = false,
      cache_enabled = true,
      wolfram_timeout_ms = 5000,
    }
    mock_state = {
      cache = {},
      active_jobs = {},
      persistent_variables = {}
    }
    mock_async = { run_job = function() end }
    mock_logger = {
      notify = function() end,
      levels = { ERROR = 1, WARN = 2, INFO = 3, DEBUG = 4 }
    }

    wolfram_to_string_spy = spy.new(function(ast)
      if ast and ast.id == "error_ast" then
        return nil, "mock codegen error"
      end
      return "wolfram_code(" .. (ast.id or "nil") .. ")"
    end)
    mock_wolfram_codegen.to_string = wolfram_to_string_spy

    async_run_job_spy = spy.new(function(cmd, expr_key, on_complete)
      on_complete(0, "mock_result", "")
      return 123
    end)
    mock_async.run_job = async_run_job_spy

    logger_notify_spy = spy.new(function() end)
    mock_logger.notify = logger_notify_spy

    original_require = _G.require
    _G.require = function(module_path)
      if module_path == 'tungsten.backends.wolfram' then return mock_wolfram_codegen end
      if module_path == 'tungsten.config' then return mock_config end
      if module_path == 'tungsten.state' then return mock_state end
      if module_path == 'tungsten.util.async' then return mock_async end
      if module_path == 'tungsten.util.logger' then return mock_logger end
      if package.loaded[module_path] then return package.loaded[module_path] end
      return original_require(module_path)
    end

    original_vim_schedule = vim.schedule
    vim.schedule = function(callback)
      callback()
    end

    clear_modules_from_cache()
    engine = require("tungsten.core.engine")
  end)

  after_each(function()
    _G.require = original_require
    vim.schedule = original_vim_schedule
    clear_modules_from_cache()
    vim_test_env.cleanup()
  end)

  describe("evaluate_async(ast, numeric, callback)", function()
    it("should successfully evaluate symbolically", function()
      local test_ast = ast_node("symbolic_expr")
      local callback_spy = spy.new()

      engine.evaluate_async(test_ast, false, function(...) callback_spy(...) end)

      assert.spy(async_run_job_spy).was.called(1)
      local cmd_args = async_run_job_spy.calls[1].vals[1]
      assert.are.same({
        "mock_wolframscript",
        "-code",
        "ToString[TeXForm[wolfram_code(symbolic_expr)], CharacterEncoding -> \"UTF8\"]"
      }, cmd_args)
      assert.spy(callback_spy).was.called_with("mock_result", nil)
    end)

    it("should successfully evaluate numerically, wrapping code with N[]", function()
      local test_ast = ast_node("numeric_expr")
      local callback_spy = spy.new()

      engine.evaluate_async(test_ast, true, function(...) callback_spy(...) end)

      assert.spy(async_run_job_spy).was.called(1)
      local cmd_args = async_run_job_spy.calls[1].vals[1]
      assert.are.same({
        "mock_wolframscript",
        "-code",
        "ToString[TeXForm[N[wolfram_code(numeric_expr)]], CharacterEncoding -> \"UTF8\"]"
      }, cmd_args)
      assert.spy(callback_spy).was.called_with("mock_result", nil)
    end)

    it("should return cached result immediately if cache is enabled and item exists", function()
      local test_ast = ast_node("cached_expr")
      local callback_spy = spy.new()
      local expr_key = engine.get_cache_key("wolfram_code(cached_expr)", false)
      mock_state.cache[expr_key] = "cached_result"

      engine.evaluate_async(test_ast, false, function(...) callback_spy(...) end)

      assert.spy(async_run_job_spy).was_not.called()
      assert.spy(callback_spy).was.called_with("cached_result", nil)
    end)

    it("should start a job and cache the result if cache is enabled and item does not exist (cache miss)", function()
      local test_ast = ast_node("new_expr")
      local callback_spy = spy.new()
      local expr_key = engine.get_cache_key("wolfram_code(new_expr)", false)

      engine.evaluate_async(test_ast, false, function(...) callback_spy(...) end)

      assert.spy(async_run_job_spy).was.called(1)
      assert.spy(callback_spy).was.called_with("mock_result", nil)
      assert.are.equal("mock_result", mock_state.cache[expr_key])
    end)

    it("should always start a job and not use/store in cache if cache is disabled", function()
      mock_config.cache_enabled = false
      local test_ast = ast_node("no_cache_expr")
      local callback_spy = spy.new()
      local expr_key = engine.get_cache_key("wolfram_code(no_cache_expr)", false)
      mock_state.cache[expr_key] = "should_not_be_used"

      engine.evaluate_async(test_ast, false, function(...) callback_spy(...) end)

      assert.spy(async_run_job_spy).was.called(1)
      assert.spy(callback_spy).was.called_with("mock_result", nil)
      assert.are.equal("should_not_be_used", mock_state.cache[expr_key])
    end)

    it("should invoke callback with error if async.run_job returns a falsy job_id", function()
      mock_async.run_job = spy.new(function() return nil end)
      local test_ast = ast_node("job_fail_ast")
      local callback_spy = spy.new()

      engine.evaluate_async(test_ast, false, function(...) callback_spy(...) end)
      assert.spy(mock_async.run_job).was.called(1)
    end)

    it("should log a notification and not start a new job if a job for the same expression is already in progress", function()
      local test_ast = ast_node("in_progress_expr")
      local callback_spy = spy.new()
      local expr_key = engine.get_cache_key("wolfram_code(in_progress_expr)", false)
      mock_state.active_jobs[999] = { expr_key = expr_key }

      engine.evaluate_async(test_ast, false, function(...) callback_spy(...) end)

      assert.spy(async_run_job_spy).was_not.called()
      assert.spy(logger_notify_spy).was.called_with(
        "Tungsten: Evaluation already in progress for this expression.",
        mock_logger.levels.INFO,
        match.is_table()
      )
    end)
  end)

  describe("Persistent Variable Substitution", function()
    it("should substitute a single persistent variable", function()
      mock_state.persistent_variables["x"] = "5"
      local result = engine.substitute_persistent_vars("x + 1", mock_state.persistent_variables)
      assert.are.equal("(5) + 1", result)
    end)

    it("should substitute multiple persistent variables", function()
      mock_state.persistent_variables = { x = "5", y = "10" }
      local result = engine.substitute_persistent_vars("x + y", mock_state.persistent_variables)
      assert.are.equal("(5) + (10)", result)
    end)

    it("should substitute longer variable names before shorter ones (e.g., 'xx' before 'x')", function()
      mock_state.persistent_variables = { x = "1", xx = "2" }
      local result = engine.substitute_persistent_vars("xx + x", mock_state.persistent_variables)
      assert.are.equal("(2) + (1)", result)
    end)

    it("should correctly handle operator precedence with parentheses around substituted values", function()
      mock_state.persistent_variables = { x = "1+1" }
      local result = engine.substitute_persistent_vars("2 * x", mock_state.persistent_variables)
      assert.are.equal("2 * (1+1)", result)
    end)

    it("should not substitute if variable name is part of a larger word/symbol", function()
      mock_state.persistent_variables = { x = "5" }
      local result = engine.substitute_persistent_vars("yxx + x", mock_state.persistent_variables)
      assert.are.equal("yxx + (5)", result)
    end)
  end)

  describe("Cache Management", function()
    it("clear_cache() should empty the cache and log", function()
      mock_state.cache["key1"] = "val1"
      engine.clear_cache()
      assert.is_true(vim.tbl_isempty(mock_state.cache))
      assert.spy(logger_notify_spy).was.called_with("Tungsten: Cache cleared.", mock_logger.levels.INFO, match.is_table())
    end)

    it("get_cache_size() should return the correct number of entries and log", function()
      mock_state.cache = { key1 = "val1", key2 = "val2" }
      local size = engine.get_cache_size()
      assert.are.equal(2, size)
      assert.spy(logger_notify_spy).was.called_with("Tungsten: Cache size: 2 entries.", mock_logger.levels.INFO, match.is_table())
    end)
  end)

  describe("Active Job Management", function()
    it("view_active_jobs() should log 'No active jobs.' if active_jobs is empty", function()
      engine.view_active_jobs()
      assert.spy(logger_notify_spy).was.called_with("Tungsten: No active jobs.", mock_logger.levels.INFO, match.is_table())
    end)

    it("view_active_jobs() should log details of active jobs", function()
      mock_state.active_jobs = {
        [123] = { bufnr = 1, expr_key = "key1", code_sent = "code1" },
        [456] = { bufnr = 2, expr_key = "key2", code_sent = "code2" },
      }
      engine.view_active_jobs()
      assert.spy(logger_notify_spy).was.called_with(match.is_string(), mock_logger.levels.INFO, match.is_table())
      local log_message = logger_notify_spy.calls[1].vals[1]
      assert.truthy(log_message:find("Active Tungsten Jobs:"))
      assert.truthy(log_message:find("ID: 123"))
      assert.truthy(log_message:find("ID: 456"))
    end)
  end)
end)
