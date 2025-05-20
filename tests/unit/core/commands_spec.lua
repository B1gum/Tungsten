-- tests/unit/core/commands_spec.lua
-- Unit tests for Neovim commands defined in core/commands.lua
---------------------------------------------------------------------

package.path = './lua/?.lua;./lua/?/init.lua;' .. package.path

local spy = require('luassert.spy')
local mock_utils = require('tests.helpers.mock_utils')
local vim_test_env = require('tests.helpers.vim_test_env')
local match = require('luassert.match')

describe("Tungsten core commands: :TungstenEvaluate", function()
  local commands
  local mock_parser
  local mock_evaluator
  local mock_selection
  local mock_insert
  local mock_config
  local mock_logger

  local modules_to_reset = {
    'tungsten.core.commands',
    'tungsten.core.parser',
    'tungsten.core.engine',
    'tungsten.util.selection',
    'tungsten.util.insert_result',
    'tungsten.config',
    'tungsten.util.logger',
  }

  before_each(function()
    vim_test_env.setup()

    mock_parser = mock_utils.mock_module('tungsten.core.parser', {
      parse = function(text)
        if text == "\\frac{1+1}{2}" then
          return { type = "fraction", numerator = { type = "binary", operator = "+", left = {type = "number", value = 1}, right = {type = "number", value = 1}}, denominator = {type = "number", value = 2} }
        elseif text == "invalid \\latex" or text == "another invalid \\latex" then

          if text == "invalid \\latex" then
             error("mock_parser_error_for_pcall_false_case")
          end
          return nil
        else
          return nil
        end
      end
    })

    mock_evaluator = mock_utils.mock_module('tungsten.core.engine', {
      evaluate_async = function(ast, numeric_mode, callback)
        if ast and ast.type == "fraction" then
          callback("1")
        else
          callback(nil)
        end
      end
    })

    mock_selection = mock_utils.mock_module('tungsten.util.selection', {
      get_visual_selection = function() return "\\frac{1+1}{2}" end
    })

    mock_insert = mock_utils.mock_module('tungsten.util.insert_result', {
      insert_result = function(_) end
    })

    mock_config = mock_utils.mock_module('tungsten.config', {
      numeric_mode = false,
      debug = false
    })

    mock_logger = mock_utils.mock_module('tungsten.util.logger', {
      notify = function() end,
      levels = { ERROR = 1, INFO = 2, DEBUG = 3, WARN = 4 }
    })

    commands = require("tungsten.core.commands")
  end)

  after_each(function()
    vim_test_env.teardown()
    mock_utils.reset_modules(modules_to_reset)
  end)

  it("should process visual selection, parse, evaluate, and insert result", function()
    local expected_selected_text = "\\frac{1+1}{2}"
    local expected_ast = { type = "fraction", numerator = { type = "binary", operator = "+", left = {type = "number", value = 1}, right = {type = "number", value = 1}}, denominator = {type = "number", value = 2} }
    local evaluation_result = "1"

    commands.tungsten_eval_command({})

    assert.spy(mock_selection.get_visual_selection).was.called(1)
    assert.spy(mock_parser.parse).was.called(1)
    assert.spy(mock_parser.parse).was.called_with(expected_selected_text)

    assert.spy(mock_evaluator.evaluate_async).was.called(1)
    local evaluate_async_calls = mock_evaluator.evaluate_async.calls
    assert.are.same(expected_ast, evaluate_async_calls[1].vals[1])
    assert.are.equal(mock_config.numeric_mode, evaluate_async_calls[1].vals[2])
    assert.is_function(evaluate_async_calls[1].vals[3])

    assert.spy(mock_insert.insert_result).was.called(1)
    assert.spy(mock_insert.insert_result).was.called_with(evaluation_result)
  end)

  it("should log an error and not proceed if no text is selected", function()
    mock_selection.get_visual_selection = spy.new(function() return "" end)

    commands.tungsten_eval_command({})

    assert.spy(mock_logger.notify).was.called(1)
    assert.spy(mock_logger.notify).was.called_with("Tungsten: No text selected.", mock_logger.levels.ERROR)
    assert.spy(mock_parser.parse).was_not.called()
    assert.spy(mock_evaluator.evaluate_async).was_not.called()
    assert.spy(mock_insert.insert_result).was_not.called()
  end)

  it("should log an error and not proceed if parser.parse fails (pcall returns false due to error)", function()
    mock_selection.get_visual_selection = spy.new(function() return "invalid \\latex" end)

    commands.tungsten_eval_command({})

    assert.spy(mock_logger.notify).was.called(1)
    assert.spy(mock_logger.notify).was.called_with(
      match.has_match("Tungsten: parse error – ") and match.has_match("mock_parser_error_for_pcall_false_case"),
      mock_logger.levels.ERROR
    )
    assert.spy(mock_evaluator.evaluate_async).was_not.called()
    assert.spy(mock_insert.insert_result).was_not.called()
  end)

  it("should log an error and not proceed if parser.parse returns nil (pcall returns true, nil)", function()
    mock_selection.get_visual_selection = spy.new(function() return "another invalid \\latex" end)

    commands.tungsten_eval_command({})

    assert.spy(mock_logger.notify).was.called(1)
    assert.spy(mock_logger.notify).was.called_with("Tungsten: parse error – nil", mock_logger.levels.ERROR)
    assert.spy(mock_evaluator.evaluate_async).was_not.called()
    assert.spy(mock_insert.insert_result).was_not.called()
  end)

  it("should not call insert_result if evaluation_async callback provides nil result", function()
    mock_evaluator.evaluate_async = spy.new(function(ast, numeric_mode, callback)
      callback(nil)
    end)

    commands.tungsten_eval_command({})
    assert.spy(mock_insert.insert_result).was_not.called()
  end)

  it("should not call insert_result if evaluation_async callback provides empty string result", function()
      mock_evaluator.evaluate_async = spy.new(function(ast, numeric_mode, callback)
        callback("")
      end)

      commands.tungsten_eval_command({})
      assert.spy(mock_insert.insert_result).was_not.called()
  end)


  it("should use numeric_mode from config when calling evaluate_async", function()
    mock_config.numeric_mode = true
    local expected_ast = { type = "fraction", numerator = { type = "binary", operator = "+", left = {type = "number", value = 1}, right = {type = "number", value = 1}}, denominator = {type = "number", value = 2} }

    commands.tungsten_eval_command({})

    assert.spy(mock_evaluator.evaluate_async).was.called(1)
    local evaluate_async_calls = mock_evaluator.evaluate_async.calls
    assert.are.same(expected_ast, evaluate_async_calls[1].vals[1])
    assert.is_true(evaluate_async_calls[1].vals[2])
  end)
end)
