-- tests/unit/core/solver_spec.lua
-- Unit tests for the Tungsten equation solver.
---------------------------------------------------------------------

local vim_test_env = require 'tests.helpers.vim_test_env'

local spy = require 'luassert.spy'
local match = require 'luassert.match'

local solver

local mock_evaluator_module
local mock_config_module
local mock_logger_module
local mock_state_module

local mock_jobstart_spy
local mock_jobstop_spy
local mock_timer_start_spy
local mock_timer_stop_spy
local mock_timer_close_spy
local mock_loop_now_spy
local mock_loop_new_timer_spy
local mock_nvim_get_current_buf_spy

local captured_timer_callback
local current_mock_time
local mock_timer_object

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

describe("tungsten.core.solver", function()
  local modules_to_clear_from_cache = {
    'tungsten.core.solver',
    'tungsten.core.parser',
    'tungsten.backends.wolfram',
    'tungsten.core.engine',
    'tungsten.config',
    'tungsten.state',
    'tungsten.util.logger',
  }

  local function clear_modules_from_cache_func()
    for _, name in ipairs(modules_to_clear_from_cache) do
      package.loaded[name] = nil
    end
  end

  local original_require
  local original_vim_fn_jobstart
  local original_vim_fn_jobstop
  local original_vim_loop_now
  local original_vim_loop_new_timer
  local original_nvim_get_current_buf

  before_each(function()
    mock_evaluator_module = {
      substitute_persistent_vars = spy.new(function(wolfram_str, persistent_vars)
        if persistent_vars and not vim.tbl_isempty(persistent_vars) then
            local result_str = wolfram_str
            for var, val in pairs(persistent_vars) do
                result_str = result_str:gsub(var, val)
            end
            return result_str
        end
        return wolfram_str
      end)
    }

    mock_config_module = {
      wolfram_path = "mock_wolframscript_path",
      debug = false,
      wolfram_timeout_ms = 5000,
    }

    mock_logger_module = {
      levels = { ERROR = 1, WARN = 2, INFO = 3, DEBUG = 4 },
      notify = spy.new(function() end)
    }

    mock_state_module = {
      persistent_variables = {},
      active_jobs = {}
    }

    current_mock_time = 1000000
    captured_timer_callback = nil

    original_require = _G.require
    _G.require = function(module_path)
      if module_path == 'tungsten.core.engine' then return mock_evaluator_module end
      if module_path == 'tungsten.config' then return mock_config_module end
      if module_path == 'tungsten.util.logger' then return mock_logger_module end
      if module_path == 'tungsten.state' then return mock_state_module end
      if module_path == 'tests.helpers.vim_test_env' then return vim_test_env end
      if package.loaded[module_path] then return package.loaded[module_path] end
      return original_require(module_path)
    end

    clear_modules_from_cache_func()

    mock_jobstart_spy = fresh_jobstart_spy()
    original_vim_fn_jobstart = vim.fn.jobstart
    vim.fn.jobstart = mock_jobstart_spy

    original_vim_fn_jobstop = vim.fn.jobstop
    mock_jobstop_spy = spy.new(function() end)
    vim.fn.jobstop = mock_jobstop_spy

    original_vim_loop_now = vim.loop.now
    mock_loop_now_spy = spy.new(function() return current_mock_time end)
    vim.loop.now = mock_loop_now_spy

    mock_timer_start_spy = spy.new(function(timer_obj, timeout, interval, callback)
        captured_timer_callback = callback
    end)
    mock_timer_stop_spy = spy.new(function() end)
    mock_timer_close_spy = spy.new(function() end)

    mock_timer_object = {
        start = mock_timer_start_spy,
        stop = mock_timer_stop_spy,
        close = mock_timer_close_spy,
        again = spy.new(function() end),
        is_active = spy.new(function() return captured_timer_callback ~= nil end),
    }

    original_vim_loop_new_timer = vim.loop.new_timer
    mock_loop_new_timer_spy = spy.new(function()
      mock_timer_start_spy:clear()
      mock_timer_stop_spy:clear()
      mock_timer_close_spy:clear()
      if mock_timer_object.again.is_spy then mock_timer_object.again:clear() end
      if mock_timer_object.is_active.is_spy then mock_timer_object.is_active:clear() end
      captured_timer_callback = nil
      return mock_timer_object
    end)
    vim.loop.new_timer = mock_loop_new_timer_spy

    original_nvim_get_current_buf = vim.api.nvim_get_current_buf
    mock_nvim_get_current_buf_spy = spy.new(function() return 1 end)
    vim.api.nvim_get_current_buf = mock_nvim_get_current_buf_spy

    solver = require("tungsten.core.solver")
  end)

  after_each(function()
    _G.require = original_require
    vim.fn.jobstart = original_vim_fn_jobstart
    vim.fn.jobstop = original_vim_fn_jobstop
    vim.loop.now = original_vim_loop_now
    vim.loop.new_timer = original_vim_loop_new_timer
    vim.api.nvim_get_current_buf = original_nvim_get_current_buf

    mock_evaluator_module.substitute_persistent_vars:clear()
    mock_logger_module.notify:clear()
    mock_jobstart_spy.fn:clear()
    mock_jobstop_spy:clear()
    mock_loop_now_spy:clear()
    mock_loop_new_timer_spy:clear()

    mock_timer_start_spy:clear()
    mock_timer_stop_spy:clear()
    mock_timer_close_spy:clear()
    if mock_timer_object and mock_timer_object.again and mock_timer_object.again.is_spy then mock_timer_object.again:clear() end
    if mock_timer_object and mock_timer_object.is_active and mock_timer_object.is_active.is_spy then mock_timer_object.is_active:clear() end

    mock_nvim_get_current_buf_spy:clear()
    clear_modules_from_cache_func()
    if vim_test_env and vim_test_env.cleanup then
      vim_test_env.cleanup()
    end
  end)

  describe("M.solve_equation_async(eq_wolfram_strs, var_wolfram_strs, is_system, callback)", function()
    local callback_spy
    local actual_callback

    before_each(function()
      callback_spy = spy.new(function() end)
      actual_callback = function(...) callback_spy(...) end
      mock_state_module.active_jobs = {}
    end)

    it("should correctly form Wolfram command for a single equation", function()
      solver.solve_equation_async({"x+1==2"}, {"x"}, false, actual_callback)
      assert.spy(mock_jobstart_spy.fn).was.called(1)
      local job_args = mock_jobstart_spy.fn.calls[1].vals[1]
      assert.are.same({ "mock_wolframscript_path", "-code", "ToString[TeXForm[Solve[{x+1==2}, {x}]], CharacterEncoding -> \"UTF8\"]" }, job_args)
    end)

    it("should correctly form Wolfram command for a system of equations", function()
      solver.solve_equation_async({"x+y==3", "x-y==1"}, {"x","y"}, true, actual_callback)
      assert.spy(mock_jobstart_spy.fn).was.called(1)
      local job_args = mock_jobstart_spy.fn.calls[1].vals[1]
      assert.are.same({ "mock_wolframscript_path", "-code", "ToString[TeXForm[Solve[{x+y==3, x-y==1}, {x, y}]], CharacterEncoding -> \"UTF8\"]" }, job_args)
    end)

    it("should log Wolfram command if debug is true", function()
      mock_config_module.debug = true
      solver.solve_equation_async({"dbg==1"}, {"dbg"}, false, actual_callback)
      assert.spy(mock_logger_module.notify).was.called_with(
        "TungstenSolve: Wolfram command: Solve[{dbg==1}, {dbg}]",
        mock_logger_module.levels.DEBUG,
        { title = "Tungsten Debug" }
      )
      mock_config_module.debug = false
    end)

    it("should handle successful job execution and parse single solution (e.g. {{x -> 1}})", function()
      solver.solve_equation_async({"x==1"}, {"x"}, false, actual_callback)
      assert.spy(mock_jobstart_spy.fn).was.called(1)
      local job_id = mock_jobstart_spy.last_returned_id
      local job_options = mock_jobstart_spy.fn.calls[1].vals[2]

      job_options.on_stdout(job_id, { "{{x -> 1}}" }, "stdout")
      job_options.on_exit(job_id, 0, "exit")
      assert.spy(callback_spy).was.called_with("1", nil)
      assert.is_nil(mock_state_module.active_jobs[job_id])
    end)

    it("should handle successful job execution and parse system solution (e.g. {{x -> 1, y -> 2}})", function()
      solver.solve_equation_async({"x==1", "y==2"}, {"x","y"}, true, actual_callback)
      assert.spy(mock_jobstart_spy.fn).was.called(1)
      local job_id = mock_jobstart_spy.last_returned_id
      local job_options = mock_jobstart_spy.fn.calls[1].vals[2]

      job_options.on_stdout(job_id, { "{{x -> 1, y -> 2}}" }, "stdout")
      job_options.on_exit(job_id, 0, "exit")

      assert.spy(callback_spy).was.called_with("x = 1, y = 2", nil)
      assert.is_nil(mock_state_module.active_jobs[job_id])
    end)
    
    it("should handle successful job execution and parse solution like {x -> 1} (single outer brace)", function()
      solver.solve_equation_async({"x==1"}, {"x"}, false, actual_callback)
      local job_id = mock_jobstart_spy.last_returned_id
      local job_options = mock_jobstart_spy.fn.calls[1].vals[2]
      job_options.on_stdout(job_id, { "{x -> 1}" }, "stdout")
      job_options.on_exit(job_id, 0, "exit")
      assert.spy(callback_spy).was.called_with("1", nil)
    end)

    it("should callback with 'No solution found' if Wolfram returns empty stdout/stderr", function()
      solver.solve_equation_async({"x==y"}, {"x"}, false, actual_callback)
      local job_id = mock_jobstart_spy.last_returned_id
      local job_options = mock_jobstart_spy.fn.calls[1].vals[2]
      job_options.on_stdout(job_id, { "" }, "stdout")
      job_options.on_stderr(job_id, { "" }, "stderr")
      job_options.on_exit(job_id, 0, "exit")
      assert.spy(callback_spy).was.called_with("No solution found", nil)
       assert.spy(mock_logger_module.notify).was.called_with(
         "TungstenSolve: Wolfram returned empty stdout and stderr. No solution found or equation not solvable.",
         mock_logger_module.levels.WARN, { title = "Tungsten Solve" }
       )
    end)

    it("should use stderr if stdout is empty but stderr has content (and exit 0)", function()
      solver.solve_equation_async({"x==1"}, {"x"}, false, actual_callback)
      local job_id = mock_jobstart_spy.last_returned_id
      local job_options = mock_jobstart_spy.fn.calls[1].vals[2]
      job_options.on_stdout(job_id, { "" }, "stdout")
      job_options.on_stderr(job_id, { "{{x -> from_stderr}}" }, "stderr")
      job_options.on_exit(job_id, 0, "exit")

      assert.spy(mock_logger_module.notify).was.called_with(
        "TungstenSolve: Wolfram returned result via stderr: {{x -> from_stderr}}",
        mock_logger_module.levels.WARN, { title = "Tungsten Solve" }
      )
      assert.spy(callback_spy).was.called_with("from_stderr", nil)
    end)

    it("should callback with raw output if solution parsing fails for system", function()
      local raw_output_for_this_test = "SomeUnparseableWolframOutput"

      solver.solve_equation_async({"a==1","b==2"}, {"a","b"}, true, actual_callback)
      local job_id = mock_jobstart_spy.last_returned_id
      local job_options = mock_jobstart_spy.fn.calls[1].vals[2]

      job_options.on_stdout(job_id, { raw_output_for_this_test }, "stdout")
      job_options.on_stderr(job_id, { "" }, "stderr")
      job_options.on_exit(job_id, 0, "exit")

      assert.spy(callback_spy).was.called_with(raw_output_for_this_test, nil)

      assert.spy(mock_logger_module.notify).was.called_with(
        "TungstenSolve: Could not parse solution from Wolfram output (general fallback): " .. raw_output_for_this_test,
        mock_logger_module.levels.WARN, { title = "Tungsten Solve" }
      )
    end)

    it("should callback with error if jobstart returns 0 (invalid args)", function()
      mock_jobstart_spy.fn = spy.new(function() return 0 end)
      solver.solve_equation_async({"x==1"}, {"x"}, false, actual_callback)
      assert.spy(callback_spy).was.called_with(nil, match.has_match("^TungstenSolve: Failed to start WolframScript job for solving%. %(Reason: Invalid arguments%)"))
      assert.spy(mock_logger_module.notify).was.called_with(
        match.has_match("^TungstenSolve: Failed to start WolframScript job for solving%. %(Reason: Invalid arguments%)"),
        mock_logger_module.levels.ERROR, { title = "Tungsten Error" }
      )
    end)

    it("should callback with error if jobstart returns -1 (cmd not found)", function()
      mock_jobstart_spy.fn = spy.new(function() return -1 end)
      solver.solve_equation_async({"x==1"}, {"x"}, false, actual_callback)
      assert.spy(callback_spy).was.called_with(nil, match.has_match("^TungstenSolve: Failed to start WolframScript job for solving%. %(Reason: Command not found%)"))
       assert.spy(mock_logger_module.notify).was.called_with(
        match.has_match("^TungstenSolve: Failed to start WolframScript job for solving%. %(Reason: Command not found%)"),
        mock_logger_module.levels.ERROR, { title = "Tungsten Error" }
      )
    end)

    it("should callback with error if WolframScript exits with non-zero code", function()
      solver.solve_equation_async({"err==1"}, {"err"}, false, actual_callback)
      local job_id = mock_jobstart_spy.last_returned_id
      local job_options = mock_jobstart_spy.fn.calls[1].vals[2]
      job_options.on_stderr(job_id, { "Wolfram error details" }, "stderr")
      job_options.on_stdout(job_id, { "Some output perhaps" }, "stdout")
      job_options.on_exit(job_id, 127, "exit")

      assert.spy(callback_spy).was.called_with(nil, match.is_string())
      local actual_err_msg = callback_spy.calls[1].vals[2]

      local expected_err_fragment = string.format("TungstenSolve: WolframScript (Job %s) error. Code: 127", tostring(job_id or 'N/A'))
      assert.is_not_nil(string.find(actual_err_msg, expected_err_fragment, 1, true), "Callback error message mismatch (job code). Got: " .. actual_err_msg)
      assert.is_not_nil(string.find(actual_err_msg, "Stderr: Wolfram error details", 1, true), "Callback error message mismatch (stderr). Got: " .. actual_err_msg)

      assert.spy(mock_logger_module.notify).was.called_with(
        match.is_string(),
        mock_logger_module.levels.ERROR, { title = "Tungsten Error" }
      )
    end)

    it("should add job to active_jobs on start and remove on exit", function()
      assert.is_true(vim.tbl_isempty(mock_state_module.active_jobs))
      solver.solve_equation_async({"active==job"}, {"active"}, false, actual_callback)
      local job_id = mock_jobstart_spy.last_returned_id
      assert.is_not_nil(job_id, "Job ID should not be nil")
      assert.is_not_nil(mock_state_module.active_jobs[job_id], "Job should be in active_jobs")
      assert.are.equal("solve:{active==job}_for_{active}", mock_state_module.active_jobs[job_id].expr_key)

      local job_options = mock_jobstart_spy.fn.calls[1].vals[2]
      job_options.on_exit(job_id, 0, "exit")
      assert.is_nil(mock_state_module.active_jobs[job_id], "Job should be removed from active_jobs")
    end)

    it("should correctly handle job timeout", function()
        mock_config_module.wolfram_timeout_ms = 50
        
        solver.solve_equation_async({"timeout==test"}, {"timeout"}, false, actual_callback)

        local job_id = mock_jobstart_spy.last_returned_id
        assert.is_not_nil(job_id, "Job ID should be returned by jobstart")
        assert.is_not_nil(mock_state_module.active_jobs[job_id], "Job should be active after start")

        mock_state_module.active_jobs[job_id].start_time = current_mock_time

        assert.spy(mock_loop_new_timer_spy).was.called(1)
        assert.spy(mock_timer_start_spy).was.called_with(mock_timer_object, 50, 0, match.is_function())

        current_mock_time = current_mock_time + mock_config_module.wolfram_timeout_ms + 10

        assert.is_function(captured_timer_callback, "Timer callback should have been captured")
        if captured_timer_callback then
          captured_timer_callback()
        else
          error("captured_timer_callback is nil, cannot trigger timer")
        end

        vim.defer_fn(function()
          assert.spy(mock_logger_module.notify).was.called_with(
              ("TungstenSolve: Wolframscript job %d timed out. Attempting to stop."):format(job_id),
              mock_logger_module.levels.WARN,
              { title = "Tungsten" }
          )
          assert.spy(mock_jobstop_spy).was.called_with(job_id)
          assert.spy(callback_spy).was_not.called()

          local job_options = mock_jobstart_spy.fn.calls[1].vals[2]
          if job_options and job_options.on_exit then
              job_options.on_exit(job_id, -15, "exit")
          else
              error("job_options or on_exit not found for job_id: " .. tostring(job_id))
          end

          assert.spy(callback_spy).was.called_with(nil, match.is_string())
          local actual_err_msg_table = callback_spy.calls[#callback_spy.calls]
          local actual_err_msg = actual_err_msg_table and actual_err_msg_table.vals[2]

          local expected_err_fragment_timeout = string.format("TungstenSolve: WolframScript (Job %s) error. Code: %s", tostring(job_id), tostring(-15))
          assert.is_not_nil(actual_err_msg and string.find(actual_err_msg, expected_err_fragment_timeout, 1, true), "Error message mismatch. Got: " .. tostring(actual_err_msg))
          assert.is_nil(mock_state_module.active_jobs[job_id])
        end, 50)
    end)
    
    it("should use default timeout if config.wolfram_timeout_ms is nil", function()
      mock_config_module.wolfram_timeout_ms = nil
      solver.solve_equation_async({"def_timeout==1"}, {"def_timeout"}, false, actual_callback)
      assert.spy(mock_loop_new_timer_spy).was.called(1)
      assert.spy(mock_timer_start_spy).was.called_with(mock_timer_object, 10000, 0, match.is_function())
    end)

    it("should close timer if job completes before timeout", function()
      solver.solve_equation_async({"x==1"}, {"x"}, false, actual_callback)
      local job_id = mock_jobstart_spy.last_returned_id
      local job_options = mock_jobstart_spy.fn.calls[1].vals[2]

      assert.spy(mock_loop_new_timer_spy).was.called(1)
      assert.spy(mock_timer_object.close).was_not.called()

      job_options.on_stdout(job_id, { "{{x -> 1}}" }, "stdout")
      job_options.on_exit(job_id, 0, "exit")
      assert.spy(mock_timer_object.close).was.called()
    end)

    it("should log error if vim.loop.new_timer returns nil", function()
        local original_vim_new_timer_func = vim.loop.new_timer
        vim.loop.new_timer = spy.new(function() return nil end)
        
        solver.solve_equation_async({"timerfail==1"}, {"timerfail"}, false, actual_callback)

        vim.loop.new_timer = original_vim_new_timer_func

        assert.spy(mock_jobstart_spy.fn).was.called(1)
        assert.spy(mock_logger_module.notify).was.called_with(
            "TungstenSolve: Failed to create job timer.",
            mock_logger_module.levels.ERROR,
            { title = "Tungsten Error" }
        )
        local job_id = mock_jobstart_spy.last_returned_id
        local job_options = mock_jobstart_spy.fn.calls[1].vals[2]
        job_options.on_stdout(job_id, { "{{timerfail -> 1}}" }, "stdout")
        job_options.on_exit(job_id, 0, "exit")
        assert.spy(callback_spy).was.called_with("1", nil)
    end)
  end)
end)
