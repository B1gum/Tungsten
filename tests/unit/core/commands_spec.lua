-- tests/unit/core/commands_spec.lua
-- Unit tests for Neovim commands defined in core/commands.lua
---------------------------------------------------------------------

package.path = './lua/?.lua;' .. package.path

local spy = require('luassert.spy')


describe("Tungsten core commands: :TungstenEval", function()
  local commands
  local mock_parser_module
  local mock_evaluator_module
  local mock_selection_module
  local mock_insert_module
  local mock_config_module
  local mock_logger_module
  local original_vim
  local original_pcall_global

  before_each(function()
    original_vim = _G.vim
    _G.vim = {
      api = {
        nvim_create_user_command = spy.new(function() end),
      },
      fn = {}
    }

    package.loaded['tungsten.core.commands'] = nil
    package.loaded['tungsten.core.parser'] = nil
    package.loaded['tungsten.core.engine'] = nil
    package.loaded['tungsten.util.selection'] = nil
    package.loaded['tungsten.util.insert_result'] = nil
    package.loaded['tungsten.config'] = nil
    package.loaded['tungsten.util.logger'] = nil

    mock_parser_module = {
      parse = spy.new(function(text)
        if text == "\\frac{1+1}{2}" then
          return { type = "fraction", numerator = { type = "binary", operator = "+", left = {type = "number", value = 1}, right = {type = "number", value = 1}}, denominator = {type = "number", value = 2} }
        else
          return nil
        end
      end)
    }
    package.loaded['tungsten.core.parser'] = mock_parser_module

    mock_evaluator_module = {
      evaluate_async = spy.new(function(ast, numeric_mode, callback)
        if ast and ast.type == "fraction" then
          callback("1")
        else
          callback(nil)
        end
      end)
    }
    package.loaded['tungsten.core.engine'] = mock_evaluator_module

    mock_selection_module = {
      get_visual_selection = spy.new(function()
        return "\\frac{1+1}{2}"
      end)
    }
    package.loaded['tungsten.util.selection'] = mock_selection_module

    mock_insert_module = {
      insert_result = spy.new(function(result_text)
      end)
    }
    package.loaded['tungsten.util.insert_result'] = mock_insert_module

    mock_config_module = {
      numeric_mode = false,
      debug = false
    }
    package.loaded['tungsten.config'] = mock_config_module

    mock_logger_module = {
      notify = spy.new(function() end),
      levels = { ERROR = 1, INFO = 2, DEBUG = 3, WARN = 4 }
    }
    package.loaded['tungsten.util.logger'] = mock_logger_module

    original_pcall_global = _G.pcall

    commands = require("tungsten.core.commands")
  end)

  after_each(function()
    _G.vim = original_vim
    _G.pcall = original_pcall_global
  end)

  it("should process visual selection, parse, evaluate, and insert result", function()
    local expected_selected_text = "\\frac{1+1}{2}"
    local expected_ast = { type = "fraction", numerator = { type = "binary", operator = "+", left = {type = "number", value = 1}, right = {type = "number", value = 1}}, denominator = {type = "number", value = 2} }
    local evaluation_result = "1"

    commands.tungsten_eval_command({})

    assert.spy(mock_selection_module.get_visual_selection).was.called(1)
    assert.spy(mock_parser_module.parse).was.called(1)
    assert.spy(mock_parser_module.parse).was.called_with(expected_selected_text)

    assert.spy(mock_evaluator_module.evaluate_async).was.called(1)
    local evaluate_async_calls = mock_evaluator_module.evaluate_async.calls
    assert.are.same(expected_ast, evaluate_async_calls[1].vals[1])
    assert.are.equal(mock_config_module.numeric_mode, evaluate_async_calls[1].vals[2])
    assert.is_function(evaluate_async_calls[1].vals[3])

    assert.spy(mock_insert_module.insert_result).was.called(1)
    assert.spy(mock_insert_module.insert_result).was.called_with(evaluation_result)
  end)

  it("should log an error and not proceed if no text is selected", function()
    mock_selection_module.get_visual_selection = spy.new(function() return "" end)

    commands.tungsten_eval_command({})

    assert.spy(mock_logger_module.notify).was.called(1)
    assert.spy(mock_logger_module.notify).was.called_with("Tungsten: No text selected.", mock_logger_module.levels.ERROR)
    assert.spy(mock_parser_module.parse).was_not.called()
    assert.spy(mock_evaluator_module.evaluate_async).was_not.called()
    assert.spy(mock_insert_module.insert_result).was_not.called()
  end)

  it("should log an error and not proceed if parser.parse fails (pcall returns false)", function()
    mock_selection_module.get_visual_selection = spy.new(function() return "invalid \\latex" end)
    mock_parser_module.parse = spy.new(function() error("mock_parser_error_for_pcall_false_case") end)

    commands.tungsten_eval_command({})

    assert.spy(mock_logger_module.notify).was.called(1)
    local logger_calls = mock_logger_module.notify.calls
    assert.is_table(logger_calls[1])
    assert.is_table(logger_calls[1].vals)
    assert.is_string(logger_calls[1].vals[1])
    assert.is_not_nil(string.find(logger_calls[1].vals[1], "Tungsten: parse error – ", 1, true), "Logged message should contain 'Tungsten: parse error – '")
    assert.is_not_nil(string.find(logger_calls[1].vals[1], "mock_parser_error_for_pcall_false_case", 1, true), "Logged message should contain the specific error from parser")
    assert.are.equal(mock_logger_module.levels.ERROR, logger_calls[1].vals[2])

    assert.spy(mock_evaluator_module.evaluate_async).was_not.called()
    assert.spy(mock_insert_module.insert_result).was_not.called()
  end)

   it("should log an error and not proceed if parser.parse returns nil (pcall returns true, nil)", function()
    mock_selection_module.get_visual_selection = spy.new(function() return "another invalid \\latex" end)
    mock_parser_module.parse = spy.new(function() return nil end)

    commands.tungsten_eval_command({})

    assert.spy(mock_logger_module.notify).was.called(1)
    local logger_calls = mock_logger_module.notify.calls
    assert.is_table(logger_calls[1])
    assert.is_table(logger_calls[1].vals)
    assert.is_string(logger_calls[1].vals[1])
    assert.are.equal("Tungsten: parse error – nil", logger_calls[1].vals[1])
    assert.are.equal(mock_logger_module.levels.ERROR, logger_calls[1].vals[2])

    assert.spy(mock_evaluator_module.evaluate_async).was_not.called()
    assert.spy(mock_insert_module.insert_result).was_not.called()
  end)


  it("should not call insert_result if evaluation_async callback provides nil or empty result", function()
    mock_evaluator_module.evaluate_async = spy.new(function(ast, numeric_mode, callback)
      callback(nil)
    end)

    commands.tungsten_eval_command({})
    assert.spy(mock_insert_module.insert_result).was_not.called()

    mock_insert_module.insert_result = spy.new(function() end)
    mock_evaluator_module.evaluate_async = spy.new(function(ast, numeric_mode, callback)
      callback("")
    end)

    commands.tungsten_eval_command({})
    assert.spy(mock_insert_module.insert_result).was_not.called()
  end)

  it("should use numeric_mode from config when calling evaluate_async", function()
    mock_config_module.numeric_mode = true
    local expected_ast = { type = "fraction", numerator = { type = "binary", operator = "+", left = {type = "number", value = 1}, right = {type = "number", value = 1}}, denominator = {type = "number", value = 2} }

    commands.tungsten_eval_command({})

    assert.spy(mock_evaluator_module.evaluate_async).was.called(1)
    local evaluate_async_calls = mock_evaluator_module.evaluate_async.calls
    assert.are.same(expected_ast, evaluate_async_calls[1].vals[1])
    assert.is_true(evaluate_async_calls[1].vals[2])
  end)
end)
