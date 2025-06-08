local spy = require 'luassert.spy'
local vim_test_env = require 'tests.helpers.vim_test_env'
local match = require 'luassert.match'

describe("Tungsten core commands", function()
  local commands_module

  local mock_parser_parse_spy
  local mock_evaluator_evaluate_async_spy
  local mock_selection_get_visual_selection_spy
  local mock_insert_result_insert_result_spy
  local mock_logger_notify_spy
  local mock_wolfram_backend_to_string_spy
  local mock_solver_solve_equation_async_spy

  local mock_parser_module
  local mock_evaluator_module
  local mock_selection_module
  local mock_insert_result_util_module
  local mock_logger_module
  local mock_state_module
  local mock_wolfram_backend_module
  local mock_solver_module
  local mock_config_module

  local original_require

  local current_get_visual_selection_text
  local current_parser_config
  local current_eval_async_config_key
  local current_to_string_config
  local current_solve_equation_config

  local eval_async_behaviors = {}
  local parser_behaviors = {}
  local wolfram_to_string_behaviors = {}

  local modules_to_clear_from_cache = {
    'tungsten.core.commands',
    'tungsten.core.parser',
    'tungsten.core.engine',
    'tungsten.core.solver',
    'tungsten.util.selection',
    'tungsten.util.insert_result',
    'tungsten.config',
    'tungsten.util.logger',
    'tungsten.state',
    'tungsten.backends.wolfram',
  }

  local function clear_modules_from_cache()
    for _, name in ipairs(modules_to_clear_from_cache) do
      package.loaded[name] = nil
    end
  end

  before_each(function()
    mock_config_module = {
      numeric_mode = false,
      debug = false,
      persistent_variable_assignment_operator = ":="
    }
    mock_parser_module = {}
    mock_evaluator_module = {}
    mock_selection_module = {}
    mock_insert_result_util_module = {}
    mock_logger_module = {}
    mock_state_module = { persistent_variables = {} }
    mock_wolfram_backend_module = {}
    mock_solver_module = {}

    original_require = _G.require
    _G.require = function(module_path)
      if module_path == 'tungsten.config' then return mock_config_module end
      if module_path == 'tungsten.core.parser' then return mock_parser_module end
      if module_path == 'tungsten.core.engine' then return mock_evaluator_module end
      if module_path == 'tungsten.util.selection' then return mock_selection_module end
      if module_path == 'tungsten.util.insert_result' then return mock_insert_result_util_module end
      if module_path == 'tungsten.util.logger' then return mock_logger_module end
      if module_path == 'tungsten.state' then return mock_state_module end
      if module_path == 'tungsten.backends.wolfram' then return mock_wolfram_backend_module end
      if module_path == 'tungsten.core.solver' then return mock_solver_module end

      if package.loaded[module_path] then return package.loaded[module_path] end
      return original_require(module_path)
    end

    clear_modules_from_cache()

    vim_test_env.set_plugin_config({'numeric_mode'}, false)
    vim_test_env.set_plugin_config({'debug'}, false)
    vim_test_env.set_plugin_config({'persistent_variable_assignment_operator'}, ":=")

    current_get_visual_selection_text = "\\frac{1+1}{2}"
    current_parser_config = {}
    current_eval_async_config_key = "default_eval"
    current_to_string_config = {}
    current_solve_equation_config = { result = "default_solution", err = nil}

    parser_behaviors.default = function(text)
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
      elseif current_parser_config[text] then
          if current_parser_config[text].error then error(current_parser_config[text].error)
          else return current_parser_config[text].output end
      end
      return { type = "unknown_expression", representation = "parsed:" .. tostring(text) }
    end
    mock_parser_parse_spy = spy.new(function(text) return parser_behaviors.default(text) end)
    mock_parser_module.parse = mock_parser_parse_spy

    eval_async_behaviors.default_eval = function(ast, numeric_mode, callback)
      if ast and ast.representation == "parsed:\\frac{1+1}{2}" then callback("1")
      elseif ast and ast.representation == "parsed:1+1" then callback("2")
      else callback(nil) end
    end
    eval_async_behaviors.numeric_eval = function(ast, numeric_mode, callback)
      if ast and ast.representation == "parsed:\\frac{1+1}{2}" then callback("1.0")
      else callback(nil) end
    end
    eval_async_behaviors.nil_eval = function(ast, numeric_mode, callback) callback(nil) end
    eval_async_behaviors.empty_string_eval = function(ast, numeric_mode, callback) callback("") end
    mock_evaluator_evaluate_async_spy = spy.new(function(ast, numeric_mode, callback)
      local behavior_func = eval_async_behaviors[current_eval_async_config_key]
      if behavior_func then behavior_func(ast, numeric_mode, callback)
      else error("Unknown current_eval_async_config_key: " .. tostring(current_eval_async_config_key)) end
    end)
    mock_evaluator_module.evaluate_async = mock_evaluator_evaluate_async_spy
    mock_evaluator_module.clear_cache = spy.new(function() end)
    mock_evaluator_module.view_active_jobs = spy.new(function() end)

    mock_selection_get_visual_selection_spy = spy.new(function() return current_get_visual_selection_text end)
    mock_selection_module.get_visual_selection = mock_selection_get_visual_selection_spy

    mock_insert_result_insert_result_spy = spy.new(function(_) end)
    mock_insert_result_util_module.insert_result = mock_insert_result_insert_result_spy

    mock_logger_notify_spy = spy.new(function () end)
    mock_logger_module.notify = mock_logger_notify_spy
    mock_logger_module.levels = { ERROR = 1, WARN = 2, INFO = 3, DEBUG = 4 }

    mock_state_module.persistent_variables = {}

    wolfram_to_string_behaviors.default = function(ast)
      if not ast then return "wolfram_conversion_error_nil_ast" end

      if current_to_string_config[ast.representation] then
          if current_to_string_config[ast.representation].error then error(current_to_string_config[ast.representation].error)
          else return current_to_string_config[ast.representation].output end
      end

      if ast.name == "quadratic_eq" then return "wolfram(quadratic_eq)" end
      if ast.name == "x" then return "wolfram(x)" end
      if ast.id == "eq1_ast" then return "wolfram(eq1_ast)" end
      if ast.id == "eq2_ast" then return "wolfram(eq2_ast)" end

      if ast.representation and string.find(ast.representation, "parsed:") then
        return string.gsub(ast.representation, "parsed:", "")
      end

      return "wolfram_conversion_failed_for_unknown_ast"
    end

    mock_wolfram_backend_to_string_spy = spy.new(function(ast) return wolfram_to_string_behaviors.default(ast) end)
    mock_wolfram_backend_module.to_string = mock_wolfram_backend_to_string_spy
    mock_wolfram_backend_module.reset_and_reinit_handlers = spy.new(function() end)

    mock_solver_solve_equation_async_spy = spy.new(function(eqs, vars, is_system, callback)
      callback(current_solve_equation_config.result, current_solve_equation_config.err)
    end)
    mock_solver_module.solve_equation_async = mock_solver_solve_equation_async_spy

    package.loaded['tungsten.config'] = mock_config_module
    package.loaded['tungsten.core.parser'] = mock_parser_module
    package.loaded['tungsten.core.engine'] = mock_evaluator_module
    package.loaded['tungsten.util.selection'] = mock_selection_module
    package.loaded['tungsten.util.insert_result'] = mock_insert_result_util_module
    package.loaded['tungsten.util.logger'] = mock_logger_module
    package.loaded['tungsten.state'] = mock_state_module
    package.loaded['tungsten.backends.wolfram'] = mock_wolfram_backend_module
    package.loaded['tungsten.core.solver'] = mock_solver_module
    commands_module = require("tungsten.core.commands")
  end)

  after_each(function()
    _G.require = original_require
    vim_test_env.cleanup()
    clear_modules_from_cache()
  end)

  describe(":TungstenEvaluate", function()
    it("should process visual selection, parse, evaluate, and insert result", function()
      current_get_visual_selection_text = "\\frac{1+1}{2}"
      current_parser_config["\\frac{1+1}{2}"] = { output = { type = "expression", representation = "parsed:\\frac{1+1}{2}" } }
      current_eval_async_config_key = "default_eval"

      commands_module.tungsten_eval_command({})

      assert.spy(mock_parser_parse_spy).was.called_with("\\frac{1+1}{2}")
      assert.spy(mock_evaluator_evaluate_async_spy).was.called(1)
      local evaluate_async_calls = mock_evaluator_evaluate_async_spy.calls
      assert.are.same({ type = "expression", representation = "parsed:\\frac{1+1}{2}" }, evaluate_async_calls[1].vals[1])
      assert.are.equal(mock_config_module.numeric_mode, evaluate_async_calls[1].vals[2])
      assert.is_function(evaluate_async_calls[1].vals[3])

      assert.spy(mock_insert_result_insert_result_spy).was.called(1)
      assert.spy(mock_insert_result_insert_result_spy).was.called_with("1")
    end)

    it("should log an error and not proceed if no text is selected", function()
      current_get_visual_selection_text = ""
      commands_module.tungsten_eval_command({})
      assert.spy(mock_logger_notify_spy).was.called_with("Tungsten: No text selected.", mock_logger_module.levels.ERROR)
    end)

    it("should log an error and not proceed if parser.parse fails (returns nil)", function()
      current_get_visual_selection_text = "invalid \\latex"
      current_parser_config["invalid \\latex"] = { output = nil }
      commands_module.tungsten_eval_command({})
      assert.spy(mock_logger_notify_spy).was.called_with("Tungsten: parse error – nil", mock_logger_module.levels.ERROR)
    end)

     it("should log an error and not proceed if parser.parse throws an error", function()
      current_get_visual_selection_text = "parser_error_latex"
      current_parser_config["parser_error_latex"] = { error = "Simulated parser error from mock_parser.parse" }

      commands_module.tungsten_eval_command({})
      assert.spy(mock_logger_notify_spy).was.called_with(
        match.is_string(function(str)
          return string.find(str, "Tungsten: parse error – ", 1, true) and
                 string.find(str, "Simulated parser error from mock_parser.parse", 1, true)
        end),
        mock_logger_module.levels.ERROR
      )
    end)

    it("should not call insert_result if evaluation_async callback provides nil result", function()
      current_get_visual_selection_text = "any valid latex"
      current_parser_config["any valid latex"] = { output = { type = "expression", representation = "parsed:any valid latex"} }
      current_eval_async_config_key = "nil_eval"

      commands_module.tungsten_eval_command({})
      assert.spy(mock_insert_result_insert_result_spy).was_not.called()
    end)

    it("should not call insert_result if evaluation_async callback provides empty string result", function()
      current_get_visual_selection_text = "any valid latex"
      current_parser_config["any valid latex"] = { output = { type = "expression", representation = "parsed:any valid latex"} }
      current_eval_async_config_key = "empty_string_eval"

      commands_module.tungsten_eval_command({})
      assert.spy(mock_insert_result_insert_result_spy).was_not.called()
    end)

    it("should use numeric_mode from config when calling evaluate_async", function()
      vim_test_env.set_plugin_config({'numeric_mode'}, true)
      current_get_visual_selection_text = "\\frac{1+1}{2}"
      current_parser_config["\\frac{1+1}{2}"] = { output = { type = "expression", representation = "parsed:\\frac{1+1}{2}" } }
      current_eval_async_config_key = "numeric_eval"

      package.loaded['tungsten.core.commands'] = nil
      local temp_commands_module = require("tungsten.core.commands")
      temp_commands_module.tungsten_eval_command({})

      assert.spy(mock_evaluator_evaluate_async_spy).was.called(1)
      local evaluate_async_calls = mock_evaluator_evaluate_async_spy.calls
      assert.are.same({ type = "expression", representation = "parsed:\\frac{1+1}{2}" }, evaluate_async_calls[1].vals[1])
      assert.is_true(evaluate_async_calls[1].vals[2])
      assert.spy(mock_insert_result_insert_result_spy).was.called_with("1.0")

      vim_test_env.set_plugin_config({'numeric_mode'}, false)
    end)
  end)

  describe("Module Reloading and State Integrity Checks", function()
    it("should ensure tungsten.state in package.loaded remains the same instance after commands.lua reload", function()
      local state_before_mock = mock_state_module
      state_before_mock.integrity_marker = "visible_before_reload"

      package.loaded['tungsten.core.commands'] = nil
      local _ = require("tungsten.core.commands")

      local state_after_reload_via_package_loaded = package.loaded['tungsten.state']
      assert.is_not_nil(state_after_reload_via_package_loaded)
      assert.are.same(state_before_mock, state_after_reload_via_package_loaded)
      assert.are.equal("visible_before_reload", state_after_reload_via_package_loaded.integrity_marker)
      state_before_mock.integrity_marker = nil
    end)
  end)


  describe(":TungstenDefinePersistentVariable", function()
    before_each(function()
      mock_state_module.persistent_variables = {}
      vim_test_env.set_plugin_config({'persistent_variable_assignment_operator'}, ":=")
      vim_test_env.set_plugin_config({'debug'}, false)
    end)

    it("should define a variable with ':=', parse its LaTeX definition, convert to Wolfram string, and store it", function()
      vim_test_env.set_plugin_config({'persistent_variable_assignment_operator'}, ":=")
      local var_name = "x"
      local latex_def = "1+1"
      local selection_str = var_name .. " := " .. latex_def
      current_get_visual_selection_text = selection_str

      current_parser_config[latex_def] = { output = { type = "expression", representation = "parsed:" .. latex_def } }
      current_to_string_config["parsed:" .. latex_def] = { output = "1+1" }

      package.loaded['tungsten.core.commands'] = nil; commands_module = require("tungsten.core.commands")
      commands_module.define_persistent_variable_command({})

      assert.spy(mock_parser_parse_spy).was.called_with(latex_def)
      assert.spy(mock_wolfram_backend_to_string_spy).was.called_with({ type = "expression", representation = "parsed:" .. latex_def })
      assert.are.same("1+1", mock_state_module.persistent_variables[var_name])
      assert.spy(mock_logger_notify_spy).was.called_with(
        "Tungsten: Defined persistent variable '" .. var_name .. "' as '" .. "1+1" .. "'.",
        mock_logger_module.levels.INFO,
        { title = "Tungsten" }
      )
    end)

    it("should define a variable with '=', parse its LaTeX definition, convert to Wolfram string, and store it (config op '=')", function()
      vim_test_env.set_plugin_config({'persistent_variable_assignment_operator'}, "=")
      local var_name = "myVar"
      local latex_def = "\\frac{a}{b}"
      local selection_str = var_name .. " = " .. latex_def
      current_get_visual_selection_text = selection_str

      current_parser_config[latex_def] = { output = { type = "expression", representation = "parsed:" .. latex_def } }
      current_to_string_config["parsed:" .. latex_def] = { output = "Divide[a,b]" }

      package.loaded['tungsten.core.commands'] = nil; commands_module = require("tungsten.core.commands")
      commands_module.define_persistent_variable_command({})

      local expected_wolfram_def = "Divide[a,b]"
      assert.spy(mock_parser_parse_spy).was.called_with(latex_def)
      assert.spy(mock_wolfram_backend_to_string_spy).was.called_with({ type = "expression", representation = "parsed:" .. latex_def })
      assert.are.same(expected_wolfram_def, mock_state_module.persistent_variables[var_name])
    end)

    it("should trim whitespace from variable name and LaTeX definition", function()
      vim_test_env.set_plugin_config({'persistent_variable_assignment_operator'}, ":=")
      local var_name = "spacedVar"
      local latex_def_untrimmed = " 1 + 1 "
      local latex_def_trimmed = "1 + 1"
      local selection_str = "  " .. var_name .. "  :=  " .. latex_def_untrimmed .. "  "
      current_get_visual_selection_text = selection_str

      current_parser_config[latex_def_trimmed] = { output = { type = "expression", representation = "parsed:" .. latex_def_trimmed } }
      current_to_string_config["parsed:" .. latex_def_trimmed] = { output = latex_def_trimmed }

      package.loaded['tungsten.core.commands'] = nil; commands_module = require("tungsten.core.commands")
      commands_module.define_persistent_variable_command({})

      assert.spy(mock_parser_parse_spy).was.called_with(latex_def_trimmed)
      assert.is_not_nil(mock_state_module.persistent_variables[var_name])
      assert.are.same(latex_def_trimmed, mock_state_module.persistent_variables[var_name])
    end)

    it("should log error if no text is selected", function()
      current_get_visual_selection_text = ""
      commands_module.define_persistent_variable_command({})
      assert.spy(mock_logger_notify_spy).was.called_with("Tungsten: No text selected for variable definition.", mock_logger_module.levels.ERROR, { title = "Tungsten Error" })
    end)

    it("should log error if no assignment operator is found", function()
      current_get_visual_selection_text = "x 1+1"
      commands_module.define_persistent_variable_command({})
      assert.spy(mock_logger_notify_spy).was.called_with("Tungsten: No assignment operator ('=' or ':=') found in selection.", mock_logger_module.levels.ERROR, { title = "Tungsten Error" })
    end)

    it("should log error if variable name is empty", function()
      current_get_visual_selection_text = " := 1+1"
      commands_module.define_persistent_variable_command({})
      assert.spy(mock_logger_notify_spy).was.called_with("Tungsten: Variable name cannot be empty.", mock_logger_module.levels.ERROR, { title = "Tungsten Error" })
    end)

    it("should log error if LaTeX definition is empty", function()
      current_get_visual_selection_text = "x := "
      commands_module.define_persistent_variable_command({})
      assert.spy(mock_logger_notify_spy).was.called_with("Tungsten: Variable definition (LaTeX) cannot be empty.", mock_logger_module.levels.ERROR, { title = "Tungsten Error" })
    end)

    it("should log error if LaTeX definition fails to parse (parser returns nil)", function()
      current_get_visual_selection_text = "y := invalid \\latex"
      current_parser_config["invalid \\latex"] = { output = nil }
      commands_module.define_persistent_variable_command({})
      assert.spy(mock_logger_notify_spy).was.called_with("Tungsten: Failed to parse LaTeX definition for 'y': nil", mock_logger_module.levels.ERROR, { title = "Tungsten Error" })
    end)

    it("should log error if LaTeX definition fails to parse (parser throws error)", function()
      current_get_visual_selection_text = "y := parser_error_latex"
      current_parser_config["parser_error_latex"] = { error = "Simulated parser error from mock_parser.parse" }
      commands_module.define_persistent_variable_command({})
      assert.spy(mock_logger_notify_spy).was.called_with(
        match.is_string(function(str)
            return string.find(str, "Tungsten: Failed to parse LaTeX definition for 'y':", 1, true) and
                   string.find(str, "Simulated parser error from mock_parser.parse", 1, true)
        end),
        mock_logger_module.levels.ERROR, { title = "Tungsten Error" }
      )
    end)

    it("should log error if AST to Wolfram string conversion fails (backend throws error)", function()
      current_get_visual_selection_text = "z := error_wolfram_conversion"
      current_parser_config["error_wolfram_conversion"] = { output = { type = "expression", representation = "parsed:error_wolfram_conversion" } }
      current_to_string_config["parsed:error_wolfram_conversion"] = { error = "Simulated Wolfram conversion error from mock_wolfram_backend.to_string" }

      commands_module.define_persistent_variable_command({})
      assert.spy(mock_logger_notify_spy).was.called_with(
        match.is_string(function(str)
            return string.find(str, "Tungsten: Failed to convert definition AST to Wolfram string for 'z':", 1, true) and
                   string.find(str, "Simulated Wolfram conversion error from mock_wolfram_backend.to_string", 1, true)
        end),
        mock_logger_module.levels.ERROR, { title = "Tungsten Error" }
      )
    end)

     it("should use default ':=' operator if config.persistent_variable_assignment_operator is invalid", function()
      vim_test_env.set_plugin_config({'persistent_variable_assignment_operator'}, "**")
      local var_name = "x_invalid_op_config"
      local latex_def = "1+1"
      local selection_str = var_name .. " := " .. latex_def
      current_get_visual_selection_text = selection_str

      current_parser_config[latex_def] = { output = {type = "expression", representation = "parsed:" .. latex_def} }
      current_to_string_config["parsed:"..latex_def] = { output = "1+1" }

      package.loaded['tungsten.core.commands'] = nil; commands_module = require("tungsten.core.commands")
      commands_module.define_persistent_variable_command({})

      assert.spy(mock_logger_notify_spy).was.called_with("Tungsten: Invalid assignment operator in config. Using ':='.", mock_logger_module.levels.WARN, { title = "Tungsten Warning" })
      assert.are.same("1+1", mock_state_module.persistent_variables[var_name])
    end)
  end)

  describe(":TungstenSolve", function()
    local original_ui_input

    before_each(function()
      vim_test_env.set_visual_selection(1, 1, 1, 15)
      current_get_visual_selection_text = "a*x^2+b*x+c=0"
      current_parser_config["a*x^2+b*x+c=0"] = { output = { type = "equation", name = "quadratic_eq" } }
      current_parser_config["x"] = { output = { type = "variable", name = "x" } }

      original_ui_input = vim.ui.input
      vim.ui.input = spy.new(function(opts, on_confirm) on_confirm("x") end)
    end)

    after_each(function()
        vim.ui.input = original_ui_input
    end)

    it("should call selection.get_visual_selection", function()
      commands_module.tungsten_solve_command({})
      assert.spy(mock_selection_get_visual_selection_spy).was.called(1)
    end)

    it("should log a warning if no text is selected", function()
      current_get_visual_selection_text = ""
      commands_module.tungsten_solve_command({})
      assert.spy(mock_logger_notify_spy).was.called_with("TungstenSolve: Selected equation text is empty. Will attempt to insert result at selection point.", mock_logger_module.levels.WARN, { title = "Tungsten Warning"})
    end)

    it("should call solver.solve_equation_async with processed ASTs and a callback", function()
      current_solve_equation_config = { result = "some_solution", err = nil }
      commands_module.tungsten_solve_command({})
      assert.spy(mock_solver_solve_equation_async_spy).was.called(1)
      assert.spy(mock_solver_solve_equation_async_spy).was.called_with({"wolfram(quadratic_eq)"}, {"wolfram(x)"}, false, match.is_function())
    end)

    it("should call insert_result when solver callback provides a solution", function()
      local mock_solution = "x = 1"
      current_solve_equation_config = { result = mock_solution, err = nil }
      commands_module.tungsten_solve_command({})
      assert.spy(mock_insert_result_insert_result_spy).was.called(1)
      assert.spy(mock_insert_result_insert_result_spy).was.called_with(mock_solution, " \\rightarrow ", match.is_table(), match.is_table(), "a*x^2+b*x+c=0")
    end)

    it("should log an error if solver callback provides an error", function()
        local mock_error_message = "Solver failed"
        current_solve_equation_config = { result = nil, err = mock_error_message }
        commands_module.tungsten_solve_command({})
        assert.spy(mock_logger_notify_spy).was.called_with("TungstenSolve: Solver error: " .. mock_error_message, mock_logger_module.levels.ERROR, { title = "Tungsten Error"})
    end)

    it("should log a warning if solver callback provides no solution (nil) and no error", function()
        current_solve_equation_config = { result = nil, err = nil }
        commands_module.tungsten_solve_command({})
        assert.spy(mock_logger_notify_spy).was.called_with("TungstenSolve: No solution found.", mock_logger_module.levels.WARN, { title = "Tungsten Warning"})
    end)

    it("should log a warning if solver callback provides empty string solution and no error", function()
        current_solve_equation_config = { result = "", err = nil }
        commands_module.tungsten_solve_command({})
        assert.spy(mock_logger_notify_spy).was.called_with("TungstenSolve: No solution found.", mock_logger_module.levels.WARN, { title = "Tungsten Warning"})
    end)
  end)

  describe(":TungstenSolveSystem", function()
    local mock_vim_ui_input_spy
    local original_vim_ui_input

    before_each(function()
      original_vim_ui_input = vim.ui.input
      mock_vim_ui_input_spy = spy.new(function(opts, on_confirm_callback)
        on_confirm_callback("x,y")
      end)
      vim.ui.input = mock_vim_ui_input_spy

      mock_selection_get_visual_selection_spy:clear()
      mock_parser_parse_spy:clear()
      mock_insert_result_insert_result_spy:clear()
      mock_logger_notify_spy:clear()
      mock_solver_solve_equation_async_spy:clear()

      current_get_visual_selection_text = "eq1=0 \\\\ eq2=0"
      current_parser_config[current_get_visual_selection_text] = {
        output = {
          type = "solve_system_equations_capture",
          equations = {
            { type = "equation", id="eq1_ast" },
            { type = "equation", id="eq2_ast" },
          }
        }
      }
      current_solve_equation_config = { result = "solution_for_system", err = nil }
    end)

    after_each(function()
      vim.ui.input = original_vim_ui_input
    end)

    it("should process visual selection, prompt for vars, parse, evaluate system, and insert result", function()
      commands_module.tungsten_solve_system_command({})
      assert.spy(mock_solver_solve_equation_async_spy).was.called(1)
      local solver_call_args = mock_solver_solve_equation_async_spy.calls[1].vals
      assert.are.same({"wolfram(eq1_ast)", "wolfram(eq2_ast)"}, solver_call_args[1])
      assert.spy(mock_insert_result_insert_result_spy).was.called(1)
    end)


    it("should log error if no text selected for equations", function()
      current_get_visual_selection_text = ""
      commands_module.tungsten_solve_system_command({})
      assert.spy(mock_logger_notify_spy).was.called_with("TungstenSolveSystem: No equations selected.", mock_logger_module.levels.ERROR, { title = "Tungsten Error" })
      assert.spy(mock_vim_ui_input_spy).was_not.called()
    end)

    it("should log error if equation parsing fails", function()
      current_get_visual_selection_text = "bad_equation_system"
      current_parser_config["bad_equation_system"] = { output = nil }
      commands_module.tungsten_solve_system_command({})
      assert.spy(mock_logger_notify_spy).was.called_with("TungstenSolveSystem: Parse error for equations: nil", mock_logger_module.levels.ERROR, { title = "Tungsten Error" })
    end)

    it("should log error if parsed AST is not 'solve_system_equations_capture'", function()
      current_get_visual_selection_text = "nota_system"
      current_parser_config["nota_system"] = { output = { type = "some_other_ast" } }
      commands_module.tungsten_solve_system_command({})
      assert.spy(mock_logger_notify_spy).was.called_with("TungstenSolveSystem: Selected text does not form a valid system of equations. Parsed as: some_other_ast", mock_logger_module.levels.ERROR, { title = "Tungsten Error" })
    end)

    it("should log error if evaluation of solve_system AST fails", function()
      current_solve_equation_config = { result = nil, err = "System evaluation error" }
      commands_module.tungsten_solve_system_command({})
      assert.spy(mock_logger_notify_spy).was.called_with("TungstenSolveSystem: Error during system evaluation: System evaluation error", mock_logger_module.levels.ERROR, { title = "Tungsten Error" })
    end)

    it("should log warning if evaluation result is nil or empty for system", function()
      current_solve_equation_config = { result = nil, err = nil }
      commands_module.tungsten_solve_system_command({})
      assert.spy(mock_logger_notify_spy).was.called_with("TungstenSolveSystem: No solution found or an issue occurred.", mock_logger_module.levels.WARN, { title = "Tungsten Warning" })
    end)
  end)
end)
