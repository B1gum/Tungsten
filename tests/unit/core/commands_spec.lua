-- tests/unit/core/commands_spec.lua
-- Unit tests for Neovim commands defined in core/commands.lua
---------------------------------------------------------------------

package.path = './lua/?.lua;./lua/?/init.lua;' .. package.path

local spy = require 'luassert.spy'
local mock_utils = require 'tests.helpers.mock_utils'
local vim_test_env = require 'tests.helpers.vim_test_env'
local match = require 'luassert.match'

describe("Tungsten core commands", function()
  local commands_ref
  local mock_parser_module_ref
  local mock_evaluator_module_ref
  local mock_selection_module_ref
  local mock_insert_result_util_module_ref
  local mock_logger_module_ref
  local mock_wolfram_backend_module_ref
  local mock_config
  local mock_state
  local captured_log_messages

  local modules_to_reset = {
    'tungsten.core.commands',
    'tungsten.core.parser',
    'tungsten.core.engine',
    'tungsten.util.selection',
    'tungsten.util.insert_result',
    'tungsten.config',
    'tungsten.util.logger',
    'tungsten.state',
    'tungsten.backends.wolfram',
  }

  before_each(function()
    vim_test_env.setup()
    commands_ref = {}
    captured_log_messages = {}

    mock_parser_module_ref = mock_utils.mock_module('tungsten.core.parser', {
      parse = function(text)
        if text == "\\frac{1+1}{2}" or text == "1+1" then
          return { type = "expression", representation = "parsed:" .. text }
        elseif text == "invalid \\latex" then
          return nil
        elseif text == "parser_error_latex" then
          error("Simulated parser error from mock_parser.parse")
        elseif text == "error_wolfram_conversion" then
          return { type = "expression", representation = "parsed:error_wolfram_conversion" }
        elseif text == "\\frac{a}{b}" then
          return { type = "expression", representation = "parsed:\\frac{a}{b}" }
        else
          return { type = "unknown_expression", representation = "parsed:" .. tostring(text) }
        end
      end
    })

    mock_evaluator_module_ref = mock_utils.mock_module('tungsten.core.engine', {
      evaluate_async = function(ast, numeric_mode, callback)
        if ast and ast.representation == "parsed:\\frac{1+1}{2}" then
          callback("1")
        elseif ast and ast.representation == "parsed:1+1" then
          callback("2")
        else
          callback(nil)
        end
      end
    })

    mock_selection_module_ref = mock_utils.mock_module('tungsten.util.selection', {
      get_visual_selection = function() return "\\frac{1+1}{2}" end
    })

    mock_insert_result_util_module_ref = mock_utils.mock_module('tungsten.util.insert_result', {
      insert_result = function(_) end
    })

    mock_config = {
      numeric_mode = false,
      debug = false,
      persistent_variable_assignment_operator = ":="
    }
    package.loaded['tungsten.config'] = mock_config

    mock_logger_module_ref = mock_utils.mock_module('tungsten.util.logger', {
      notify = function () end,
      levels = { ERROR = 1, WARN = 2, INFO = 3, DEBUG = 4 }
    })

    mock_state = {
      persistent_variables = {}
    }
    package.loaded['tungsten.state'] = mock_state


    mock_wolfram_backend_module_ref = mock_utils.mock_module('tungsten.backends.wolfram', {
      to_string = function(ast)
        if ast and ast.representation then
          if ast.representation == "parsed:1+1" then return "1+1"
          elseif ast.representation == "parsed:\\frac{a}{b}" then return "Divide[a,b]"
          elseif ast.representation == "parsed:error_wolfram_conversion" then error("Simulated Wolfram conversion error from mock_wolfram_backend.to_string")
          end
          return "wolfram(" .. ast.representation .. ")"
        end
        return "wolfram_conversion_failed_for_ast_nil_representation"
      end
    })

    mock_utils.reset_modules({'tungsten.core.commands'})
    commands_ref.instance = require("tungsten.core.commands")
  end)

  after_each(function()
    vim_test_env.teardown()
    mock_utils.reset_modules(modules_to_reset)
  end)

  describe(":TungstenEvaluate", function()
    it("should process visual selection, parse, evaluate, and insert result", function()
      mock_selection_module_ref.get_visual_selection = function() return "\\frac{1+1}{2}" end
      local expected_selected_text = "\\frac{1+1}{2}"
      local expected_ast = { type = "expression", representation = "parsed:" .. expected_selected_text }
      local evaluation_result = "1"

      if mock_parser_module_ref.parse.clear then mock_parser_module_ref.parse:clear() end


      commands_ref.instance.tungsten_eval_command({})

      assert.spy(mock_parser_module_ref.parse).was.called_with(expected_selected_text) 

      assert.spy(mock_evaluator_module_ref.evaluate_async).was.called(1)
      local evaluate_async_calls = mock_evaluator_module_ref.evaluate_async.calls
      assert.are.same(expected_ast, evaluate_async_calls[1].vals[1])
      assert.are.equal(mock_config.numeric_mode, evaluate_async_calls[1].vals[2])
      assert.is_function(evaluate_async_calls[1].vals[3])

      assert.spy(mock_insert_result_util_module_ref.insert_result).was.called(1)
      assert.spy(mock_insert_result_util_module_ref.insert_result).was.called_with(evaluation_result)
    end)

    it("should log an error and not proceed if no text is selected", function()
      mock_selection_module_ref.get_visual_selection = function() return "" end
      commands_ref.instance.tungsten_eval_command({})
      assert.spy(mock_logger_module_ref.notify).was.called_with("Tungsten: No text selected.", mock_logger_module_ref.levels.ERROR)
    end)

    it("should log an error and not proceed if parser.parse fails (returns nil)", function()
      mock_selection_module_ref.get_visual_selection = function() return "invalid \\latex" end
      commands_ref.instance.tungsten_eval_command({})
      assert.spy(mock_logger_module_ref.notify).was.called_with("Tungsten: parse error – nil", mock_logger_module_ref.levels.ERROR)
    end)

     it("should log an error and not proceed if parser.parse throws an error", function()
      mock_selection_module_ref.get_visual_selection = function() return "parser_error_latex" end
      commands_ref.instance.tungsten_eval_command({})
      assert.spy(mock_logger_module_ref.notify).was.called_with(
        match.is_string(function(str)
          return string.find(str, vim.pesc("Tungsten: parse error – "), 1, true) and
                 string.find(str, vim.pesc("Simulated parser error from mock_parser.parse"), 1, true)
        end),
        mock_logger_module_ref.levels.ERROR
      )
    end)

    it("should not call insert_result if evaluation_async callback provides nil result", function()
      mock_selection_module_ref.get_visual_selection = function() return "any valid latex" end
      local old_eval_async = mock_evaluator_module_ref.evaluate_async
      mock_evaluator_module_ref.evaluate_async = function(ast, numeric_mode, callback) callback(nil) end
      commands_ref.instance.tungsten_eval_command({})
      assert.spy(mock_insert_result_util_module_ref.insert_result).was_not.called()
      mock_evaluator_module_ref.evaluate_async = old_eval_async
    end)

    it("should not call insert_result if evaluation_async callback provides empty string result", function()
      mock_selection_module_ref.get_visual_selection = function() return "any valid latex" end
      local old_eval_async = mock_evaluator_module_ref.evaluate_async
      mock_evaluator_module_ref.evaluate_async = function(ast, numeric_mode, callback) callback("") end
      commands_ref.instance.tungsten_eval_command({})
      assert.spy(mock_insert_result_util_module_ref.insert_result).was_not.called()
      mock_evaluator_module_ref.evaluate_async = old_eval_async
    end)

    it("should use numeric_mode from config when calling evaluate_async", function()
      mock_config.numeric_mode = true
      local selected_text = "\\frac{1+1}{2}"
      mock_selection_module_ref.get_visual_selection = function() return selected_text end
      local expected_ast = { type = "expression", representation = "parsed:" .. selected_text }
      commands_ref.instance.tungsten_eval_command({})
      assert.spy(mock_evaluator_module_ref.evaluate_async).was.called(1)
      local evaluate_async_calls = mock_evaluator_module_ref.evaluate_async.calls
      assert.are.same(expected_ast, evaluate_async_calls[1].vals[1])
      assert.is_true(evaluate_async_calls[1].vals[2])
    end)
  end)

  describe("Module Reloading and State Integrity Checks", function()
    it("should ensure tungsten.state in package.loaded remains the same mock_state instance after commands.lua reload", function()
      assert.is_not_nil(package.loaded['tungsten.state'], "Pre-condition: tungsten.state should be in package.loaded")
      assert.are.same(mock_state, package.loaded['tungsten.state'], "Pre-condition: package.loaded['tungsten.state'] should be the test's mock_state instance.")

      local state_instance_before_commands_reload = package.loaded['tungsten.state']
      mock_state.integrity_marker = "visible_before_reload"

      mock_utils.reset_modules({'tungsten.core.commands'})
      local temp_commands_instance = require("tungsten.core.commands")

      assert.is_not_nil(temp_commands_instance, "Failed to re-require commands.lua")

      local state_instance_after_commands_reload = package.loaded['tungsten.state']

      assert.is_not_nil(state_instance_after_commands_reload, "tungsten.state became nil in package.loaded after commands reload.")
      assert.are.same(mock_state, state_instance_after_commands_reload,
        "package.loaded['tungsten.state'] is no longer the original mock_state instance after commands.lua reload.")
      assert.are.same(state_instance_before_commands_reload, state_instance_after_commands_reload,
        "package.loaded['tungsten.state'] changed instance after commands.lua reload.")
      assert.are.equal("visible_before_reload", state_instance_after_commands_reload.integrity_marker,
        "Marker set on mock_state before commands reload is not visible on the instance from package.loaded after reload.")
      mock_state.integrity_marker = nil
    end)
  end)


  describe(":TungstenDefinePersistentVariable", function()
    before_each(function()
      mock_state.persistent_variables = {}
      mock_config.persistent_variable_assignment_operator = ":="
    end)

    it("should define a variable with ':=', parse its LaTeX definition, convert to Wolfram string, and store it", function()
      local var_name = "x"
      local latex_def = "1+1"
      local selection_str = var_name .. " := " .. latex_def
      mock_selection_module_ref.get_visual_selection = function() return selection_str end
      local expected_ast = { type = "expression", representation = "parsed:" .. latex_def }
      local expected_wolfram_def = "1+1"
      commands_ref.instance.define_persistent_variable_command({})
      assert.spy(mock_parser_module_ref.parse).was.called_with(latex_def)
      assert.spy(mock_wolfram_backend_module_ref.to_string).was.called_with(expected_ast)
      assert.are.same(expected_wolfram_def, mock_state.persistent_variables[var_name])
    end)

    it("should define a variable with '=', parse its LaTeX definition, convert to Wolfram string, and store it", function()
      mock_config.persistent_variable_assignment_operator = "="
      local var_name = "myVar"
      local latex_def = "\\frac{a}{b}"
      local selection_str = var_name .. " = " .. latex_def
      mock_selection_module_ref.get_visual_selection = function() return selection_str end
      local temp_commands_instance

      local old_parser_parse = mock_parser_module_ref.parse
      mock_parser_module_ref.parse = function(text) if text == latex_def then return { type = "expression", representation = "parsed:" .. latex_def } else return old_parser_parse(text) end end
      local old_wolfram_to_string = mock_wolfram_backend_module_ref.to_string
      mock_wolfram_backend_module_ref.to_string = function(ast) if ast and ast.representation == "parsed:" .. latex_def then return "Divide[a,b]" else return old_wolfram_to_string(ast) end end

      mock_utils.reset_modules({'tungsten.core.commands'})
      temp_commands_instance = require("tungsten.core.commands")
      temp_commands_instance.define_persistent_variable_command({})

      local expected_wolfram_def = "Divide[a,b]"
      assert.are.same(expected_wolfram_def, mock_state.persistent_variables[var_name])

      mock_parser_module_ref.parse = old_parser_parse
      mock_wolfram_backend_module_ref.to_string = old_wolfram_to_string
    end)

    it("should trim whitespace from variable name and LaTeX definition", function()
      local var_name = "spacedVar"
      local latex_def_untrimmed = " 1 + 1 "
      local latex_def_trimmed = "1 + 1"
      local selection_str = "  " .. var_name .. "  :=  " .. latex_def_untrimmed .. "  "
      mock_selection_module_ref.get_visual_selection = function() return selection_str end
      local temp_commands_instance

      local parse_call_arg_trim_test = nil
      local old_parser_parse = mock_parser_module_ref.parse
      mock_parser_module_ref.parse = function(text)
          parse_call_arg_trim_test = text
          if text == latex_def_trimmed then return { type = "expression", representation = "parsed:" .. latex_def_trimmed } end
          return nil
      end
      local old_wolfram_to_string = mock_wolfram_backend_module_ref.to_string
      mock_wolfram_backend_module_ref.to_string = function(ast)
          if ast and ast.representation == "parsed:" .. latex_def_trimmed then return latex_def_trimmed end
          return nil
      end

      mock_utils.reset_modules({'tungsten.core.commands'})
      temp_commands_instance = require("tungsten.core.commands")
      temp_commands_instance.define_persistent_variable_command({})

      assert.are.equal(latex_def_trimmed, parse_call_arg_trim_test) 
      assert.is_not_nil(mock_state.persistent_variables[var_name])
      assert.are.same(latex_def_trimmed, mock_state.persistent_variables[var_name])

      mock_parser_module_ref.parse = old_parser_parse
      mock_wolfram_backend_module_ref.to_string = old_wolfram_to_string
    end)

    it("should log error if no text is selected", function()
      mock_selection_module_ref.get_visual_selection = function() return "" end
      commands_ref.instance.define_persistent_variable_command({})
      assert.spy(mock_logger_module_ref.notify).was.called_with("Tungsten: No text selected for variable definition.", mock_logger_module_ref.levels.ERROR, { title = "Tungsten Error" })
    end)

    it("should log error if no assignment operator is found", function()
      mock_selection_module_ref.get_visual_selection = function() return "x 1+1" end
      commands_ref.instance.define_persistent_variable_command({})
      assert.spy(mock_logger_module_ref.notify).was.called_with("Tungsten: No assignment operator ('=' or ':=') found in selection.", mock_logger_module_ref.levels.ERROR, { title = "Tungsten Error" })
    end)

    it("should try alternative operator if configured one is not found", function()
      local original_debug_config = mock_config.debug
      mock_config.persistent_variable_assignment_operator = "="
        local var_name = "x"
        local latex_def = "1+1"
        local selection_str = var_name .. " := " .. latex_def
        mock_selection_module_ref.get_visual_selection = function() return selection_str end
        local temp_commands_instance

        local test_case_marker = "alt_op_original_failing_test_marker"
        local expected_ast_for_this_test = {
          type = "expression",
          representation = "parsed:" .. latex_def,
          marker = test_case_marker
        }
        local expected_wolfram_str_for_this_test = "wolfram_output_for_" .. var_name .. "_" .. latex_def

        local old_parser_parse = mock_parser_module_ref.parse
        mock_parser_module_ref.parse = function(text)
          if text == latex_def then
            return expected_ast_for_this_test
          else
            return old_parser_parse(text)
          end
        end
        local old_wolfram_to_string = mock_wolfram_backend_module_ref.to_string
        mock_wolfram_backend_module_ref.to_string = function(ast)
          if ast and ast.marker == test_case_marker then
            return expected_wolfram_str_for_this_test
          else
            return old_wolfram_to_string(ast)
          end
        end

        mock_utils.reset_modules({'tungsten.core.commands'})
        temp_commands_instance = require("tungsten.core.commands")
        temp_commands_instance.define_persistent_variable_command({})

        assert.are.same(expected_wolfram_str_for_this_test, mock_state.persistent_variables[var_name], "Variable '"..var_name.."' was not stored correctly or with the expected value when using alternative operator.")

        mock_parser_module_ref.parse = old_parser_parse
        mock_wolfram_backend_module_ref.to_string = old_wolfram_to_string
        mock_config.debug = original_debug_config
    end)


    it("should correctly update mock_state when alternative operator is used (focused check)", function()
      local original_debug_config = mock_config.debug
      mock_config.persistent_variable_assignment_operator = "="
      local var_name = "z_alt_focus_check"
      local latex_def = "alt_op_focus_test_latex"
      local selection_str = var_name .. " := " .. latex_def
      mock_selection_module_ref.get_visual_selection = function() return selection_str end

      local parser_called_correctly = false
      local wolfram_converter_called_correctly = false
      local unique_ast_for_this_test = { type = "expression", representation = "parsed:" .. latex_def, source_marker = "alt_op_focus_test_ast" }
      local expected_wolfram_string = "wolfram_for_" .. latex_def

      local old_parser_parse = mock_parser_module_ref.parse
      mock_parser_module_ref.parse = function(text)
        if text == latex_def then
          parser_called_correctly = true
          return unique_ast_for_this_test
        end
        return old_parser_parse(text)
      end

      local old_wolfram_to_string = mock_wolfram_backend_module_ref.to_string
      mock_wolfram_backend_module_ref.to_string = function(ast)
        if ast and ast.source_marker == "alt_op_focus_test_ast" then
          wolfram_converter_called_correctly = true
          return expected_wolfram_string
        end
        return old_wolfram_to_string(ast)
      end

      mock_utils.reset_modules({'tungsten.core.commands'})
      local temp_commands_instance = require("tungsten.core.commands")
      temp_commands_instance.define_persistent_variable_command({})

      assert.is_true(parser_called_correctly, "Parser was not called with the correct RHS LaTeX for the focused alternative operator test.")
      assert.is_true(wolfram_converter_called_correctly, "Wolfram converter was not called with the correct AST for the focused alternative operator test.")

      assert.are.same(expected_wolfram_string, mock_state.persistent_variables[var_name],
        "Variable '" ..var_name.. "' was not stored with the expected Wolfram string using the alternative operator path in focused test.")

      mock_parser_module_ref.parse = old_parser_parse
      mock_wolfram_backend_module_ref.to_string = old_wolfram_to_string
      mock_config.debug = original_debug_config
    end)

    it("should log error if variable name is empty", function()
      mock_selection_module_ref.get_visual_selection = function() return " := 1+1" end
      commands_ref.instance.define_persistent_variable_command({})
      assert.spy(mock_logger_module_ref.notify).was.called_with("Tungsten: Variable name cannot be empty.", mock_logger_module_ref.levels.ERROR, { title = "Tungsten Error" })
    end)

    it("should log error if LaTeX definition is empty", function()
      mock_selection_module_ref.get_visual_selection = function() return "x := " end
      commands_ref.instance.define_persistent_variable_command({})
      assert.spy(mock_logger_module_ref.notify).was.called_with("Tungsten: Variable definition (LaTeX) cannot be empty.", mock_logger_module_ref.levels.ERROR, { title = "Tungsten Error" })
    end)

    it("should log error if LaTeX definition fails to parse (parser returns nil)", function()
      mock_selection_module_ref.get_visual_selection = function() return "y := invalid \\latex" end
      commands_ref.instance.define_persistent_variable_command({})
      assert.spy(mock_logger_module_ref.notify).was.called_with("Tungsten: Failed to parse LaTeX definition for 'y': nil", mock_logger_module_ref.levels.ERROR, { title = "Tungsten Error" })
    end)

    it("should log error if LaTeX definition fails to parse (parser throws error)", function()
      mock_selection_module_ref.get_visual_selection = function() return "y := parser_error_latex" end
      commands_ref.instance.define_persistent_variable_command({})
      assert.spy(mock_logger_module_ref.notify).was.called_with(
        match.is_string(function(str)
            return string.find(str, vim.pesc("Tungsten: Failed to parse LaTeX definition for 'y':"), 1, true) and
                   string.find(str, vim.pesc("Simulated parser error from mock_parser.parse"), 1, true)
        end),
        mock_logger_module_ref.levels.ERROR, { title = "Tungsten Error" }
      )
    end)

    it("should log error if AST to Wolfram string conversion fails (backend throws error)", function()
      mock_selection_module_ref.get_visual_selection = function() return "z := error_wolfram_conversion" end
      commands_ref.instance.define_persistent_variable_command({})
      assert.spy(mock_logger_module_ref.notify).was.called_with(
        match.is_string(function(str)
            return string.find(str, vim.pesc("Tungsten: Failed to convert definition AST to Wolfram string for 'z':"), 1, true) and
                   string.find(str, vim.pesc("Simulated Wolfram conversion error from mock_wolfram_backend.to_string"), 1, true)
        end),
        mock_logger_module_ref.levels.ERROR, { title = "Tungsten Error" }
      )
    end)

     it("should use default ':=' operator if config.persistent_variable_assignment_operator is invalid", function()
      mock_config.persistent_variable_assignment_operator = "**"
      local var_name = "x"
      local latex_def = "1+1"
      local selection_str = var_name .. " := " .. latex_def
      mock_selection_module_ref.get_visual_selection = function() return selection_str end
      local temp_commands_instance

      local old_parser_parse = mock_parser_module_ref.parse
      mock_parser_module_ref.parse = function(text) if text == latex_def then return {type = "expression", representation = "parsed:" .. latex_def} else return old_parser_parse(text) end end
      local old_wolfram_to_string = mock_wolfram_backend_module_ref.to_string
      mock_wolfram_backend_module_ref.to_string = function(ast) if ast and ast.representation == "parsed:"..latex_def then return "1+1" else return old_wolfram_to_string(ast) end end

      mock_utils.reset_modules({'tungsten.core.commands'})
      temp_commands_instance = require("tungsten.core.commands")
      temp_commands_instance.define_persistent_variable_command({})

      assert.spy(mock_logger_module_ref.notify).was.called_with("Tungsten: Invalid assignment operator in config. Using ':='.", mock_logger_module_ref.levels.WARN, { title = "Tungsten Warning" })
      assert.are.same("1+1", mock_state.persistent_variables[var_name])

      mock_parser_module_ref.parse = old_parser_parse
      mock_wolfram_backend_module_ref.to_string = old_wolfram_to_string
    end)
  end)
end)
