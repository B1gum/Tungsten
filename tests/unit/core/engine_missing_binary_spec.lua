
local spy = require 'luassert.spy'

describe("engine missing binary feedback", function()
  local engine
  local mock_wolfram_codegen
  local mock_config
  local mock_state
  local mock_async
  local mock_logger
  local async_run_job_spy
  local callback_spy
  local mock_exit_code

  local original_require
  local original_vim_schedule

  local modules_to_clear = {
    'tungsten.core.engine',
    'tungsten.backends.wolfram',
    'tungsten.config',
    'tungsten.state',
    'tungsten.util.async',
    'tungsten.util.logger',
  }

  local function clear_modules()
    for _, name in ipairs(modules_to_clear) do
      package.loaded[name] = nil
    end
  end

  local function ast()
    return { type = 'expression', id = 'test_ast' }
  end

  before_each(function()
    mock_wolfram_codegen = { to_string = function() return 'wolfram_code' end }
    mock_config = {
      wolfram_path = 'mock_wolframscript',
      numeric_mode = false,
      debug = false,
      cache_enabled = false,
      wolfram_timeout_ms = 5000,
    }
    mock_state = { cache = {}, active_jobs = {}, persistent_variables = {} }
    mock_logger = { notify = function() end, levels = { ERROR=1, WARN=2, INFO=3, DEBUG=4 } }
    mock_logger.debug = function(t,m) mock_logger.notify(m, mock_logger.levels.DEBUG, { title=t }) end
    mock_logger.info  = function(t,m) mock_logger.notify(m, mock_logger.levels.INFO, { title=t }) end
    mock_logger.warn  = function(t,m) mock_logger.notify(m, mock_logger.levels.WARN, { title=t }) end
    mock_logger.error = function(t,m) mock_logger.notify(m, mock_logger.levels.ERROR, { title=t }) end

    async_run_job_spy = spy.new(function(_, opts)
      if opts.on_exit then opts.on_exit(mock_exit_code or -1, '', '') end
      return { id = 1, cancel = function() end, is_active = function() return false end }
    end)
    mock_async = { run_job = async_run_job_spy }

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
    vim.schedule = function(fn) fn() end

    clear_modules()
    engine = require('tungsten.core.engine')
  end)

  after_each(function()
    _G.require = original_require
    vim.schedule = original_vim_schedule
    clear_modules()
  end)

  local function run_with_code(code)
    mock_exit_code = code
    callback_spy = spy.new()
    engine.evaluate_async(ast(), false, function(...) callback_spy(...) end)
  end

  it('returns helpful message when exit code is -1', function()
    run_with_code(-1)
    assert.spy(callback_spy).was.called_with(nil, 'WolframScript not found. Check wolfram_path.')
  end)

  it('returns helpful message when exit code is 127', function()
    run_with_code(127)
    assert.spy(callback_spy).was.called_with(nil, 'WolframScript not found. Check wolfram_path.')
  end)
end)

