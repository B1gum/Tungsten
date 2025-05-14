-- tests/core/engine_cache_spec.lua


describe("core.engine cache functionality", function()
  local engine
  local state
  local config
  local logger

  local mock_vim_fn_jobstart_func
  local jobstart_calls
  local mock_wolfram_to_string_func

  local test_ast = { type = "number", value = 123 }
  local test_wolfram_code = "123"
  local test_result = "Result for 123"

  local original_vim_fn_jobstart
  local original_logger_notify
  local original_wolfram_to_string
  local original_nvim_get_current_buf
  local original_vim_loop_now


  local function reset_internal_mocks_and_state()
    jobstart_calls = {}
    mock_vim_fn_jobstart_func = function(command_args, opts)
      table.insert(jobstart_calls, { args = command_args, opts = opts })
      local job_id = #jobstart_calls
      if opts and opts.on_exit then
        if opts.on_stdout then
          opts.on_stdout(job_id, {test_result}, "stdout")
        end
        opts.on_exit(job_id, 0, "exit")
      end
      return job_id
    end

    mock_wolfram_to_string_func = function(ast_param)
      if ast_param == test_ast then
        return test_wolfram_code
      end
      return "unknown_ast_to_string_for_mock"
    end

    if state then
      state.cache = {}
      state.active_jobs = {}
    end

    if config then
      config.cache_enabled = true
      config.debug = false
      config.numeric_mode = false
    end
  end

  before_each(function()
    -- Store originals and set up mocks
    _G.vim = _G.vim or {}
    _G.vim.fn = _G.vim.fn or {}
    original_vim_fn_jobstart = _G.vim.fn.jobstart
    _G.vim.fn.jobstart = function(...) return mock_vim_fn_jobstart_func(...) end

    _G.vim.api = _G.vim.api or {}
    original_nvim_get_current_buf = _G.vim.api.nvim_get_current_buf
    _G.vim.api.nvim_get_current_buf = function() return 1 end

    _G.vim.loop = _G.vim.loop or {}
    original_vim_loop_now = _G.vim.loop.now
    _G.vim.loop.now = function() return 0 end

    -- Clear cache for modules to be re-required with mocks
    package.loaded["tungsten.util.logger"] = nil
    package.loaded["tungsten.state"] = nil
    package.loaded["tungsten.config"] = nil
    package.loaded["tungsten.backends.wolfram"] = nil
    package.loaded["tungsten.core.engine"] = nil

    logger = require("tungsten.util.logger")
    original_logger_notify = logger.notify
    logger.notify = function() end -- Suppress logs during test

    state = require("tungsten.state")
    config = require("tungsten.config")

    local wolfram_backend = require("tungsten.backends.wolfram")
    original_wolfram_to_string = wolfram_backend.to_string
    wolfram_backend.to_string = function(...) return mock_wolfram_to_string_func(...) end

    engine = require("tungsten.core.engine")

    reset_internal_mocks_and_state()
  end)

  after_each(function()
    -- Restore mocked globals and module functions
    _G.vim.fn.jobstart = original_vim_fn_jobstart
    _G.vim.api.nvim_get_current_buf = original_nvim_get_current_buf
    _G.vim.loop.now = original_vim_loop_now

    if original_logger_notify then
      package.loaded["tungsten.util.logger"] = nil -- Ensure clean slate if re-required
      local fresh_logger = require("tungsten.util.logger")
      fresh_logger.notify = original_logger_notify
    end
    if original_wolfram_to_string then
       package.loaded["tungsten.backends.wolfram"] = nil
       local fresh_backend = require("tungsten.backends.wolfram")
       fresh_backend.to_string = original_wolfram_to_string
    end

    -- Clear loaded packages to ensure fresh state for next test if necessary,
    -- though careful restoration of functions is often preferred.
    package.loaded["tungsten.state"] = nil
    package.loaded["tungsten.config"] = nil
    package.loaded["tungsten.core.engine"] = nil
  end)

  describe("cache hits", function()
    it("should return cached result without calling WolframScript if cache_enabled is true", function()
      state.cache[test_wolfram_code .. "::symbolic"] = "cached_result_123"
      local received_result, received_err

      engine.evaluate_async(test_ast, false, function(result, err)
        received_result = result
        received_err = err
      end)

      assert.is_nil(received_err)
      assert.are.equal("cached_result_123", received_result)
      assert.are.equal(0, #jobstart_calls, "WolframScript should not have been called")
    end)
  end)

  describe("cache misses", function()
    it("should call WolframScript and cache the result if cache_enabled is true", function()
      assert.is_nil(state.cache[test_wolfram_code .. "::symbolic"], "Cache should be empty for this key initially")
      local received_result, received_err

      engine.evaluate_async(test_ast, false, function(result, err)
        received_result = result
        received_err = err
      end)

      assert.is_nil(received_err)
      assert.are.equal(test_result, received_result)
      assert.are.equal(1, #jobstart_calls, "WolframScript should have been called once")
      assert.are.equal(test_result, state.cache[test_wolfram_code .. "::symbolic"], "Result should be cached")
    end)

    it("should handle numeric mode for cache key correctly", function()
      assert.is_nil(state.cache[test_wolfram_code .. "::numeric"], "Cache should be empty for numeric key initially")
      local received_result, received_err

      engine.evaluate_async(test_ast, true, function(result, err)
        received_result = result
        received_err = err
      end)

      assert.is_nil(received_err)
      assert.are.equal(test_result, received_result)
      assert.are.equal(1, #jobstart_calls)
      assert.are.equal(test_result, state.cache[test_wolfram_code .. "::numeric"], "Numeric result should be cached")
    end)
  end)

  describe("cache disabling", function()
    it("should not retrieve from cache if cache_enabled is false", function()
      config.cache_enabled = false
      state.cache[test_wolfram_code .. "::symbolic"] = "cached_result_should_not_be_used"
      local received_result, received_err

      engine.evaluate_async(test_ast, false, function(result, err)
        received_result = result
        received_err = err
      end)

      assert.is_nil(received_err)
      assert.are.equal(test_result, received_result)
      assert.are.equal(1, #jobstart_calls, "WolframScript should have been called")
    end)

    it("should not store to cache if cache_enabled is false", function()
      config.cache_enabled = false
      local received_result, received_err

      engine.evaluate_async(test_ast, false, function(result, err)
        received_result = result
        received_err = err
      end)

      assert.is_nil(received_err)
      assert.are.equal(test_result, received_result)
      assert.are.equal(1, #jobstart_calls)
      assert.is_nil(state.cache[test_wolfram_code .. "::symbolic"], "Result should not have been cached")
    end)
  end)

  describe("clear_cache()", function()
    it("should empty the cache", function()
      state.cache["key1"] = "val1"
      state.cache["key2"] = "val2"
      assert.is_not_nil(state.cache["key1"])

      engine.clear_cache()
      assert.is_nil(next(state.cache), "Cache should be empty after clear_cache")
    end)
  end)

  describe("get_cache_size()", function()
    it("should return 0 for an empty cache", function()
      engine.clear_cache() -- Ensure it's empty
      
      -- To test the logging, we need to temporarily restore and capture logger.notify
      local logged_messages = {}
      local actual_logger_notify = require("tungsten.util.logger").notify -- Get the potentially mocked one
      require("tungsten.util.logger").notify = function(msg, level, opts) -- Temporarily override for capture
          table.insert(logged_messages, {msg=msg, level=level, opts=opts})
      end

      local size = engine.get_cache_size()
      assert.are.equal(0, size)
      assert.truthy(#logged_messages > 0 and logged_messages[1].msg:find("Cache size: 0 entries."), "Should log correct size")

      require("tungsten.util.logger").notify = actual_logger_notify -- Restore to what it was at start of this test
    end)

    it("should return the correct number of entries in the cache", function()
      engine.clear_cache()
      state.cache["key1"] = "val1"
      state.cache["key2"] = "val2"
      state.cache["key3"] = "val3"

      local logged_messages = {}
      local actual_logger_notify = require("tungsten.util.logger").notify
      require("tungsten.util.logger").notify = function(msg, level, opts)
          table.insert(logged_messages, {msg=msg, level=level, opts=opts})
      end

      local size = engine.get_cache_size()
      assert.are.equal(3, size)
      assert.truthy(#logged_messages > 0 and logged_messages[1].msg:find("Cache size: 3 entries."), "Should log correct size")
      
      require("tungsten.util.logger").notify = actual_logger_notify
    end)
  end)
end)
