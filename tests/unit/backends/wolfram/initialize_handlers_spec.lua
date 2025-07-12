-- tungsten/tests/unit/backends/wolfram/initialize_handlers_spec.lua

local spy = require('luassert.spy')
local test_env = require('tests.helpers.vim_test_env')

local function simple_inspect(tbl)
  if type(tbl) ~= "table" then
    return tostring(tbl)
  end
  local parts = {}
  for k, v in pairs(tbl) do
    table.insert(parts, tostring(k) .. ": " .. simple_inspect(v))
  end
  return "{ " .. table.concat(parts, ", ") .. " }"
end

describe("tungsten.backends.wolfram (Plenary Env)", function()
  local wolfram_backend
  local current_priority_mode

  local get_domain_priority_spy
  local logger_notify_spy
  local render_render_spy

  local tungsten_config_module
  local tungsten_registry_module
  local tungsten_logger_module
  local tungsten_render_module

  local original_require
  local require_calls
  local mock_domain_handler_definitions

  local original_methods = {}

  local all_test_domain_module_paths = {
    "tungsten.domains.arithmetic.wolfram_handlers",
    "tungsten.domains.custom_domain_one.wolfram_handlers",
    "tungsten.domains.custom_domain_two.wolfram_handlers",
    "tungsten.domains.high_prio_domain.wolfram_handlers",
    "tungsten.domains.low_prio_domain.wolfram_handlers",
    "tungsten.domains.successful_domain.wolfram_handlers",
    "tungsten.domains.missing_domain.wolfram_handlers",
    "tungsten.domains.nohandlers_domain.wolfram_handlers",
    "tungsten.domains.another_good_domain.wolfram_handlers",
    "tungsten.domains.invalid_domain_for_no_handler_test.wolfram_handlers",
    "tungsten.domains.another_good_domain_for_nohandlers_test.wolfram_handlers",
    "tungsten.domains.nil_return_domain.wolfram_handlers",
    "tungsten.domains.non_existent_domain_one.wolfram_handlers",
    "tungsten.domains.non_existent_domain_two.wolfram_handlers",
  }

  local function clear_tungsten_modules_from_cache()
    package.loaded['tungsten.backends.wolfram'] = nil
    package.loaded['tungsten.config'] = nil
    package.loaded['tungsten.core.registry'] = nil
    package.loaded['tungsten.util.logger'] = nil
    package.loaded['tungsten.core.render'] = nil
    for _, path in ipairs(all_test_domain_module_paths) do
      package.loaded[path] = nil
    end
    if mock_domain_handler_definitions then
        for path, _ in pairs(mock_domain_handler_definitions) do
            package.loaded[path] = nil
        end
    end
  end

  before_each(function()
    current_priority_mode = "default"
    clear_tungsten_modules_from_cache()
    original_methods = {}

    tungsten_config_module = require('tungsten.config')
    tungsten_registry_module = require('tungsten.core.registry')
    tungsten_logger_module = require('tungsten.util.logger')
    tungsten_render_module = require('tungsten.core.render')

    test_env.set_plugin_config({ 'debug' }, false)
    test_env.set_plugin_config({ 'domains' }, nil)

    if tungsten_registry_module then
        original_methods.get_domain_priority = tungsten_registry_module.get_domain_priority

        get_domain_priority_spy = spy.new(function() return 0 end)

        local spy_obj_type = type(get_domain_priority_spy)

        if spy_obj_type == "table" then
            local keys = {}
            for k, v_type in pairs(get_domain_priority_spy) do table.insert(keys, k .. " (type: " .. type(v_type) .. ")") end
        elseif spy_obj_type == "function" then
             local mt = getmetatable(get_domain_priority_spy)
             if mt then
                local mt_keys = {}
                for k, v_type in pairs(mt) do table.insert(mt_keys, k .. " (type: " .. type(v_type) .. ")") end
             else
                print("DIAGNOSTIC: get_domain_priority_spy is a function with no metatable.")
             end
        end

        if spy.is_spy and type(spy.is_spy) == "function" then
            if not spy.is_spy(get_domain_priority_spy) then
                print("DIAGNOSTIC: spy.is_spy(get_domain_priority_spy) returned FALSE!")
            end
        elseif not spy.is_spy or type(spy.is_spy) ~= "function" then
             print("DIAGNOSTIC: spy.is_spy function itself is not available or not a function (type: " .. type(spy.is_spy) .. ").")
        end

        tungsten_registry_module.get_domain_priority = get_domain_priority_spy
    else
        error("tungsten_registry_module is nil, cannot set spy for get_domain_priority")
    end

    if tungsten_render_module then
        original_methods.render = tungsten_render_module.render

        render_render_spy = spy.new(function(ast_node, handlers_table)
            if ast_node and ast_node.type then
                if handlers_table and type(handlers_table) == "table" then
                    local actual_handler_to_call = handlers_table[ast_node.type]
                    if actual_handler_to_call then
                        if type(actual_handler_to_call) == "table" or type(actual_handler_to_call) == "function" then
                            local result_val = actual_handler_to_call(ast_node, function() return "dummy_recursive_call_output_from_render_spy" end)
                            return result_val
                        else
                            return "ERROR_HANDLER_NOT_CALLABLE_IN_RENDER_SPY"
                        end
                    else
                    end
                else
                end
            else
            end
            return "FALLBACK_FROM_RENDER_SPY_NEW_NO_HANDLER"
        end)

        tungsten_render_module.render = render_render_spy

    else
        error("tungsten_render_module is nil, cannot set spy for render")
    end



    if tungsten_logger_module then
        original_methods.notify = tungsten_logger_module.notify
        logger_notify_spy = spy.new(function() end)
        tungsten_logger_module.notify = logger_notify_spy
        tungsten_logger_module.debug = function(t,m) logger_notify_spy(m, tungsten_logger_module.levels.DEBUG, { title = t }) end
        tungsten_logger_module.info = function(t,m) logger_notify_spy(m, tungsten_logger_module.levels.INFO, { title = t }) end
        tungsten_logger_module.warn = function(t,m) logger_notify_spy(m, tungsten_logger_module.levels.WARN, { title = t }) end
        tungsten_logger_module.error = function(t,m) logger_notify_spy(m, tungsten_logger_module.levels.ERROR, { title = t }) end
    else
        error("tungsten_logger_module is nil, cannot set spy for notify")
    end

    assert(get_domain_priority_spy and type(get_domain_priority_spy.callback) == "function",
           "Spy for 'get_domain_priority_spy' MUST have a .callback function. Spy Type: " .. type(get_domain_priority_spy) ..
           ", .callback type: " .. type(get_domain_priority_spy and get_domain_priority_spy.callback))

    original_methods.get_domain_priority = tungsten_registry_module.get_domain_priority

    local main_priority_logic_func = function(domain_name)
      local received_domain_name_str = tostring(domain_name)
      local priority_to_return

      if current_priority_mode == "conflict_test" then
        if received_domain_name_str == "custom_domain_one" then priority_to_return = 200
        elseif received_domain_name_str == "high_prio_domain" then priority_to_return = 200
        elseif received_domain_name_str == "custom_domain_two" then priority_to_return = 90
        elseif received_domain_name_str == "arithmetic" then priority_to_return = 100
        else
          priority_to_return = 0
        end
      else
        if received_domain_name_str == "arithmetic" then priority_to_return = 100
        elseif received_domain_name_str == "custom_domain_one" then priority_to_return = 110
        elseif received_domain_name_str == "custom_domain_two" then priority_to_return = 90
        elseif received_domain_name_str == "high_prio_domain" then priority_to_return = 200
        elseif received_domain_name_str == "low_prio_domain" then priority_to_return = 50
        elseif received_domain_name_str == "successful_domain" then priority_to_return = 120
        elseif received_domain_name_str == "missing_domain" then priority_to_return = 10
        elseif received_domain_name_str == "nohandlers_domain" then priority_to_return = 20
        elseif received_domain_name_str == "another_good_domain" then priority_to_return = 130
        elseif received_domain_name_str == "another_good_domain_for_nohandlers_test" then priority_to_return = 40
        elseif received_domain_name_str == "nil_return_domain" then priority_to_return = 25
        else
          priority_to_return = 0
        end
      end

      return priority_to_return
    end


    get_domain_priority_spy = spy.new(main_priority_logic_func)
    tungsten_registry_module.get_domain_priority = get_domain_priority_spy


    if not (render_render_spy and type(render_render_spy.callback) == "function") then
         error(string.format("Spy for 'render_render_spy' does not have a .callback method. Spy type: %s, .callback type: %s. Available keys: %s",
            type(render_render_spy),
            type(render_render_spy and render_render_spy.callback),
            simple_inspect(render_render_spy)))
    end
   render_render_spy:callback(function(ast_node, handlers_table)
     print("\n[[[[[ render_render_spy CALLBACK START ]]]]]")
     if ast_node and ast_node.type then
       print(string.format("    RENDER_SPY: ast_node.type = %s", ast_node.type))
       if handlers_table then
         local handler_func_from_table = handlers_table[ast_node.type]
         print(string.format("    RENDER_SPY: handlers_table['%s'] is type %s, value: %s", ast_node.type, type(handler_func_from_table), tostring(handler_func_from_table)))

         if handler_func_from_table then
           local actual_handler_to_call = handler_func_from_table
           local spy_name = "unknown_function_or_not_a_direct_test_spy"

           print(string.format("    RENDER_SPY: Attempting to call handler. Identified (best effort) as: %s", spy_name))

           local result = actual_handler_to_call(ast_node, function() return "dummy_recursive_call_output" end)
           print(string.format("    RENDER_SPY: Handler returned: %s", tostring(result)))
           print("[[[[[ render_render_spy CALLBACK END (handler called) ]]]]]")
           return result
         else
           print(string.format("    RENDER_SPY: No handler in handlers_table for type '%s'", ast_node.type))
         end
       else
         print("    RENDER_SPY: handlers_table is nil")
       end
     else
       print("    RENDER_SPY: ast_node or ast_node.type is nil")
     end
     print("[[[[[ render_render_spy CALLBACK END (FALLBACK) ]]]]]")
     return "mock_render_FALLBACK_NO_HANDLER_FOR_TYPE"
   end)


    mock_domain_handler_definitions = {}
    require_calls = {}
    original_require = _G.require

    _G.require = function(module_path)
      table.insert(require_calls, module_path)
      if module_path == 'tungsten.config' then return tungsten_config_module end
      if module_path == 'tungsten.core.registry' then return tungsten_registry_module end
      if module_path == 'tungsten.util.logger' then return tungsten_logger_module end
      if module_path == 'tungsten.core.render' then
        return tungsten_render_module
      end

      if mock_domain_handler_definitions[module_path] then
        if type(mock_domain_handler_definitions[module_path]) == 'function' then
          local status, res_or_err = pcall(mock_domain_handler_definitions[module_path])
          if not status then error(res_or_err) end
          return res_or_err
        end
        return mock_domain_handler_definitions[module_path]
      end

      if module_path == "tungsten.domains.arithmetic.wolfram_handlers" then
          return { handlers = { mock_arith_op_handler_fallback = function() end } }
      end
      if string.find(module_path, "tungsten.domains%.[^%.]+%.wolfram_handlers") then
        return nil 
      end
      return original_require(module_path)
    end

    wolfram_backend = _G.require("tungsten.backends.wolfram")
  end)

  after_each(function()
    _G.require = original_require

    if tungsten_registry_module and original_methods.get_domain_priority then
      tungsten_registry_module.get_domain_priority = original_methods.get_domain_priority
    end
    if tungsten_render_module and original_methods.render then
      tungsten_render_module.render = original_methods.render
    end
    if tungsten_logger_module and original_methods.notify then
      tungsten_logger_module.notify = original_methods.notify
    end

    if spy and type(spy.reset_all) == "function" then
        spy.reset_all()
    end

    test_env.restore_plugin_configs()
    clear_tungsten_modules_from_cache()
    mock_domain_handler_definitions = nil
    original_methods = nil
  end)

  describe("Default Handler Loading (config.domains is nil or empty)", function()
    it("should attempt to load arithmetic handlers if config.domains is nil", function()
      test_env.set_plugin_config({ 'domains' }, nil)
      mock_domain_handler_definitions["tungsten.domains.arithmetic.wolfram_handlers"] = {
        handlers = { arith_specific_handler_nil_config = function() end }
      }
      wolfram_backend.reload_handlers()

      local found_arithmetic_handler_require = false
      for _, called_module in ipairs(require_calls) do
        if called_module == "tungsten.domains.arithmetic.wolfram_handlers" then
          found_arithmetic_handler_require = true
          break
        end
      end
      assert.is_true(found_arithmetic_handler_require, "Expected _G.require to be called for 'tungsten.domains.arithmetic.wolfram_handlers'")
      assert.spy(get_domain_priority_spy).was.called_with("arithmetic")
    end)

    it("should attempt to load arithmetic handlers if config.domains is an empty table", function()
      test_env.set_plugin_config({ 'domains' }, {})
      mock_domain_handler_definitions["tungsten.domains.arithmetic.wolfram_handlers"] = {
        handlers = { arith_specific_handler_empty_config = function() end }
      }
      wolfram_backend.reload_handlers()

      local found_arithmetic_handler_require = false
      for _, called_module in ipairs(require_calls) do
        if called_module == "tungsten.domains.arithmetic.wolfram_handlers" then
          found_arithmetic_handler_require = true
          break
        end
      end
      assert.is_true(found_arithmetic_handler_require, "Expected _G.require to be called for 'tungsten.domains.arithmetic.wolfram_handlers'")
      assert.spy(get_domain_priority_spy).was.called_with("arithmetic")
    end)
  end)

  describe("Custom Domain Handler Loading", function()
    it("should attempt to load handlers from a single domain specified in config.domains", function()
      local domain_name = "custom_domain_one"
      local handler_module_path = "tungsten.domains." .. domain_name .. ".wolfram_handlers"
      test_env.set_plugin_config({ 'domains' }, { domain_name })

      mock_domain_handler_definitions[handler_module_path] = {
        handlers = { custom_op_one = function() return "custom_one_output" end }
      }
      mock_domain_handler_definitions["tungsten.domains.arithmetic.wolfram_handlers"] = nil


      wolfram_backend.reload_handlers()

      local found_custom_handler_require = false
      for _, called_module in ipairs(require_calls) do
        if called_module == handler_module_path then
          found_custom_handler_require = true
          break
        end
      end
      assert.is_true(found_custom_handler_require, "Expected _G.require to be called for '" .. handler_module_path .. "'")
      assert.spy(get_domain_priority_spy).was.called_with(domain_name)

      local found_arithmetic_handler_require = false
      for _, called_module in ipairs(require_calls) do
        if called_module == "tungsten.domains.arithmetic.wolfram_handlers" then
          found_arithmetic_handler_require = true
          break
        end
      end
      assert.is_false(found_arithmetic_handler_require, "Did not expect _G.require for 'arithmetic' when not in config.domains and custom domains are specified.")
    end)

    it("should attempt to load handlers from multiple domains specified in config.domains", function()
      local domain_names = { "custom_domain_one", "custom_domain_two" }
      test_env.set_plugin_config({ 'domains' }, domain_names)

      local handler_module_path_one = "tungsten.domains.custom_domain_one.wolfram_handlers"
      local handler_module_path_two = "tungsten.domains.custom_domain_two.wolfram_handlers"

      mock_domain_handler_definitions[handler_module_path_one] = {
        handlers = { custom_op_one = function() end }
      }
      mock_domain_handler_definitions[handler_module_path_two] = {
        handlers = { custom_op_two = function() end }
      }
      mock_domain_handler_definitions["tungsten.domains.arithmetic.wolfram_handlers"] = nil

      wolfram_backend.reload_handlers()

      local require_calls_for_custom_domains = {}
      for _, called_module in ipairs(require_calls) do
        if called_module == handler_module_path_one or called_module == handler_module_path_two then
          require_calls_for_custom_domains[called_module] = true
        end
      end
      assert.is_true(require_calls_for_custom_domains[handler_module_path_one], "Expected _G.require for '" .. handler_module_path_one .. "'")
      assert.is_true(require_calls_for_custom_domains[handler_module_path_two], "Expected _G.require for '" .. handler_module_path_two .. "'")
      assert.spy(get_domain_priority_spy).was.called_with("custom_domain_one")
      assert.spy(get_domain_priority_spy).was.called_with("custom_domain_two")
    end)

    it("should also load arithmetic handlers if 'arithmetic' is explicitly in config.domains along with custom domains", function()
      local custom_domain = "custom_domain_one"
      test_env.set_plugin_config({ 'domains' }, { "arithmetic", custom_domain })


      local arithmetic_handler_module_path = "tungsten.domains.arithmetic.wolfram_handlers"
      local custom_handler_module_path = "tungsten.domains." .. custom_domain .. ".wolfram_handlers"

      mock_domain_handler_definitions[arithmetic_handler_module_path] = {
        handlers = { arith_op = function() end }
      }
      mock_domain_handler_definitions[custom_handler_module_path] = {
        handlers = { custom_op = function() end }
      }

      wolfram_backend.reload_handlers()

      local called_modules_map = {}
      for _, called_module in ipairs(require_calls) do
        called_modules_map[called_module] = true
      end

      assert.is_true(called_modules_map[arithmetic_handler_module_path], "Expected require for arithmetic handlers")
      assert.is_true(called_modules_map[custom_handler_module_path], "Expected require for custom_domain_one handlers")
      assert.spy(get_domain_priority_spy).was.called_with("arithmetic")
      assert.spy(get_domain_priority_spy).was.called_with(custom_domain)
    end)
  end)

  describe("Handler Prioritization and Overriding", function()
    local low_prio_handler_spy_func, high_prio_handler_spy_func
    local common_node_type = "common_node"
    local test_ast

    before_each(function()
      test_env.set_plugin_config({ 'debug' }, true)
      low_prio_handler_spy_func = spy.new(function() return "low_prio_output" end)
      high_prio_handler_spy_func = spy.new(function() return "high_prio_output" end)
      test_ast = { type = common_node_type, data = "some_data" }
    end)

    it("should use handler from higher priority domain (high_prio domain in config AFTER low_prio)", function()
      test_env.set_plugin_config({ 'domains' }, { "low_prio_domain", "high_prio_domain" })


      local low_prio_path = "tungsten.domains.low_prio_domain.wolfram_handlers"
      local high_prio_path = "tungsten.domains.high_prio_domain.wolfram_handlers"

      mock_domain_handler_definitions[low_prio_path] = {
        handlers = { [common_node_type] = low_prio_handler_spy_func, unrelated_low = function() end }
      }
      mock_domain_handler_definitions[high_prio_path] = {
        handlers = { [common_node_type] = high_prio_handler_spy_func, unrelated_high = function() end }
      }
      mock_domain_handler_definitions["tungsten.domains.arithmetic.wolfram_handlers"] = nil

      wolfram_backend.reload_handlers()
      local result = wolfram_backend.to_string(test_ast)

      local override_log_found = false
      local expected_log_message = ("Wolfram Backend: Handler for node type '%s': high_prio_domain (Prio 200) overrides low_prio_domain (Prio 50)."):format(common_node_type)
      local expected_log_level = tungsten_logger_module.levels.DEBUG
      local expected_title = "Tungsten Backend"

      for _, call_info in ipairs(logger_notify_spy.calls) do
        local call_args = call_info.vals
        if call_args and #call_args >= 3 then
          local msg, level, opts = call_args[1], call_args[2], call_args[3]
          if type(msg) == "string" and msg == expected_log_message and level == expected_log_level and opts and opts.title == expected_title then
            override_log_found = true
            break
          end
        end
      end
      assert.is_true(override_log_found, "Expected debug log for handler override was not found. Logged: " .. simple_inspect(logger_notify_spy.calls))

      assert.spy(high_prio_handler_spy_func).was.called(1)
      assert.spy(low_prio_handler_spy_func).was_not.called()
      assert.are.equal("high_prio_output", result)

      local render_calls = render_render_spy.calls
      assert.are.equal(1, #render_calls)
      assert.are.same(test_ast, render_calls[1].vals[1])
      assert.is_table(render_calls[1].vals[2])
      assert.are.same(high_prio_handler_spy_func, render_calls[1].vals[2][common_node_type])
      assert.is_function(render_calls[1].vals[2]["unrelated_low"])
      assert.is_function(render_calls[1].vals[2]["unrelated_high"])
    end)

    it("should use handler from higher priority domain (high_prio domain in config BEFORE low_prio - testing 'NOT overriding' log)", function()
      test_env.set_plugin_config({ 'domains' }, { "high_prio_domain", "low_prio_domain" })
      test_env.set_plugin_config({ 'debug' }, true)


      local low_prio_path = "tungsten.domains.low_prio_domain.wolfram_handlers"
      local high_prio_path = "tungsten.domains.high_prio_domain.wolfram_handlers"

      mock_domain_handler_definitions[low_prio_path] = {
        handlers = { [common_node_type] = low_prio_handler_spy_func }
      }
      mock_domain_handler_definitions[high_prio_path] = {
        handlers = { [common_node_type] = high_prio_handler_spy_func }
      }
      mock_domain_handler_definitions["tungsten.domains.arithmetic.wolfram_handlers"] = nil

      wolfram_backend.reload_handlers()
      local result = wolfram_backend.to_string(test_ast)

      local not_override_log_found = false
      local expected_log_message = ("Wolfram Backend: Handler for node type '%s' from low_prio_domain (Prio 50) NOT overriding existing from high_prio_domain (Prio 200)."):format(common_node_type)
      local expected_log_level = tungsten_logger_module.levels.DEBUG
      local expected_title = "Tungsten Backend"

      for _, call_info in ipairs(logger_notify_spy.calls) do
        local call_args = call_info.vals
        if call_args and #call_args >= 3 then
          local msg, level, opts = call_args[1], call_args[2], call_args[3]
          if type(msg) == "string" and msg == expected_log_message and level == expected_log_level and opts and opts.title == expected_title then
            not_override_log_found = true
            break
          end
        end
      end
      assert.is_true(not_override_log_found, "Expected debug log for 'NOT overriding' was not found. Logged: " .. simple_inspect(logger_notify_spy.calls))

      assert.spy(high_prio_handler_spy_func).was.called(1)
      assert.spy(low_prio_handler_spy_func).was_not.called()
      assert.are.equal("high_prio_output", result)
    end)

    it("should log a warning and pick one for same priority conflict", function()
      current_priority_mode = "conflict_test"

      test_env.set_plugin_config({ 'domains' }, { "custom_domain_one", "high_prio_domain", "custom_domain_two" })
      test_env.set_plugin_config({ 'debug' }, true)

      assert(get_domain_priority_spy and type(get_domain_priority_spy.callback) == "function",
        "Global get_domain_priority_spy or its .callback method is not available for this test's local override.")

      get_domain_priority_spy:callback(function(domain_name)
        local received_domain_name_str = tostring(domain_name)
        print("[[[[[ CONFLICT TEST SPY_CALLBACK START for get_domain_priority ]]]]]")
        print(string.format("    CONFLICT_TEST_CALLBACK: Received domain_name = '%s' (type: %s)", received_domain_name_str, type(domain_name)))

        local priority

        if received_domain_name_str == "custom_domain_one" then priority = 200
        elseif received_domain_name_str == "high_prio_domain" then priority = 200
        elseif received_domain_name_str == "custom_domain_two" then priority = 90
        elseif received_domain_name_str == "arithmetic" then priority = 100
        else
            priority = 0
            print(string.format("    CONFLICT_TEST_CALLBACK: Domain '%s' not listed, defaulting to 0.", received_domain_name_str))
        end
        print(string.format("    CONFLICT_TEST_CALLBACK: For '%s', returning %s", received_domain_name_str, tostring(priority)))
        print("[[[[[ CONFLICT TEST SPY_CALLBACK END for get_domain_priority ]]]]]")
        return priority
      end)

      local common_node_type = "common_node" 
      local test_ast = { type = common_node_type, data = "some_data" }

      local handler_spy_custom_one = spy.new(function() return "custom_one_output" end)
      local handler_spy_high_prio = spy.new(function() return "high_prio_output" end)

      local path_custom_one = "tungsten.domains.custom_domain_one.wolfram_handlers"
      local path_high_prio = "tungsten.domains.high_prio_domain.wolfram_handlers"
      local path_custom_two = "tungsten.domains.custom_domain_two.wolfram_handlers"

      mock_domain_handler_definitions[path_custom_one] = {
          handlers = { [common_node_type] = handler_spy_custom_one, other_op_one = function() end }
      }
      mock_domain_handler_definitions[path_high_prio] = {
          handlers = { [common_node_type] = handler_spy_high_prio, other_op_high = function() end }
      }
      mock_domain_handler_definitions[path_custom_two] = {
          handlers = { another_op = function() end }
      }
      mock_domain_handler_definitions["tungsten.domains.arithmetic.wolfram_handlers"] = nil

      wolfram_backend.reload_handlers()
      local result = wolfram_backend.to_string(test_ast)

      local conflict_log_found = false
      local expected_log_message = ("Wolfram Backend: Handler for node type '%s': CONFLICT - %s and %s have same priority (%d). '%s' takes precedence (due to processing order). Consider adjusting priorities."):format(
          common_node_type, "high_prio_domain", "custom_domain_one", 200, "high_prio_domain"
      )
      local expected_log_level = tungsten_logger_module.levels.WARN
      local expected_title = "Tungsten Backend Warning"
      local logged_calls_str = simple_inspect(logger_notify_spy.calls)

      for _, call_info in ipairs(logger_notify_spy.calls) do
          local call_args = call_info.vals
          if call_args and #call_args >= 3 then
              local msg, level, opts = call_args[1], call_args[2], call_args[3]
              if type(msg) == "string" and msg == expected_log_message and
                 level == expected_log_level and opts and opts.title == expected_title then
                  conflict_log_found = true
                  break
              end
          end
      end
      assert.is_true(conflict_log_found, "Expected WARN log for handler conflict was not found or was incorrect. \nExpected: [" .. expected_log_message .. "]\nActual Logged Messages: " .. logged_calls_str)

      assert.spy(handler_spy_high_prio).was.called(1)
      assert.spy(handler_spy_custom_one).was_not.called()
      assert.are.equal("high_prio_output", result)
    end)
  end)

  describe("Handling of Domain Modules", function()
    it("should successfully load and process handlers from a correctly defined domain module", function()
      local domain_name = "successful_domain"
      local handler_module_path = "tungsten.domains." .. domain_name .. ".wolfram_handlers"
      test_env.set_plugin_config({ 'domains' }, { domain_name })
      test_env.set_plugin_config({ 'debug' }, true)


      local success_handler_spy_func = spy.new(function() return "success_domain_output" end)
      mock_domain_handler_definitions[handler_module_path] = {
        handlers = { specific_op = success_handler_spy_func }
      }
      mock_domain_handler_definitions["tungsten.domains.arithmetic.wolfram_handlers"] = nil

      wolfram_backend.reload_handlers()

      local found_require = false
      for _, called_module in ipairs(require_calls) do
        if called_module == handler_module_path then
          found_require = true
          break
        end
      end
      assert.is_true(found_require, "Expected _G.require to be called for '" .. handler_module_path .. "'")
      assert.spy(get_domain_priority_spy).was.called_with(domain_name)

      local success_log_found = false
      local domain_priority = 120
      local expected_log_message = ("Wolfram Backend: Successfully loaded handlers module from %s for domain %s (Priority: %d)"):format(handler_module_path, domain_name, domain_priority)
      for _, call_info in ipairs(logger_notify_spy.calls) do
        if call_info.vals[1] == expected_log_message and call_info.vals[2] == tungsten_logger_module.levels.DEBUG then
          success_log_found = true
          break
        end
      end
      assert.is_true(success_log_found, "Expected debug log for successful handler loading not found. Logged: " .. simple_inspect(logger_notify_spy.calls))

      local test_ast = { type = "specific_op" }
      local result = wolfram_backend.to_string(test_ast)
      assert.spy(success_handler_spy_func).was.called(1)
      assert.are.equal("success_domain_output", result)
    end)

    it("should log a warning and continue if a domain module is missing (require throws error)", function()
      local missing_domain_name = "missing_domain"
      local another_good_domain_name = "another_good_domain"
      local handler_module_path_missing = "tungsten.domains." .. missing_domain_name .. ".wolfram_handlers"
      local handler_module_path_good = "tungsten.domains." .. another_good_domain_name .. ".wolfram_handlers"

      test_env.set_plugin_config({ 'domains' }, { missing_domain_name, another_good_domain_name })

      local test_specific_original_require = _G.require
      _G.require = function(module_path)
          table.insert(require_calls, module_path)
          if module_path == handler_module_path_missing then
              error("Simulated error: module '" .. module_path .. "' not found by test override.")
          elseif mock_domain_handler_definitions[module_path] then
              return mock_domain_handler_definitions[module_path]
          elseif module_path == 'tungsten.config' then
              return tungsten_config_module
          elseif module_path == 'tungsten.core.registry' then
              return tungsten_registry_module
          elseif module_path == 'tungsten.util.logger' then
              return tungsten_logger_module
          elseif module_path == 'tungsten.core.render' then
            return tungsten_render_module
          end
          return original_require(module_path)
      end

      local good_handler_spy_func = spy.new(function() return "good_output" end)
      mock_domain_handler_definitions[handler_module_path_good] = {
        handlers = { good_op = good_handler_spy_func }
      }
      mock_domain_handler_definitions["tungsten.domains.arithmetic.wolfram_handlers"] = nil


      wolfram_backend.reload_handlers()

      local warning_log_found = false
      local simulated_error_fragment = "Simulated error: module '" .. handler_module_path_missing .. "' not found by test override."
      local expected_log_message_pattern_start = ("Wolfram Backend: Could not load Wolfram handlers for domain '%s'. Failed to load module '%s': "):format(missing_domain_name, handler_module_path_missing)

      for _, call_info in ipairs(logger_notify_spy.calls) do
        local msg, level, opts = call_info.vals[1], call_info.vals[2], call_info.vals[3]
        if type(msg) == "string" and
           string.sub(msg, 1, #expected_log_message_pattern_start) == expected_log_message_pattern_start and
           string.find(msg, simulated_error_fragment, 1, true) and
           level == tungsten_logger_module.levels.WARN and opts and opts.title == "Tungsten Backend Warning" then
          warning_log_found = true
          break
        end
      end
      assert.is_true(warning_log_found, "Expected WARN log for missing domain module (erroring require) not found or incorrect. Logged: " .. simple_inspect(logger_notify_spy.calls))

      local test_ast = { type = "good_op" }
      local result = wolfram_backend.to_string(test_ast)
      assert.spy(good_handler_spy_func).was.called(1)
      assert.are.equal("good_output", result)

      _G.require = test_specific_original_require
    end)

    it("should log a warning if a domain module is loaded but does not have a .handlers table", function()
      local nohandlers_domain_name = "nohandlers_domain"
      local another_good_domain_name = "another_good_domain_for_nohandlers_test"
      test_env.set_plugin_config({ 'domains' }, { nohandlers_domain_name, another_good_domain_name })

      local handler_module_path_nohandlers = "tungsten.domains." .. nohandlers_domain_name .. ".wolfram_handlers"
      local handler_module_path_good = "tungsten.domains." .. another_good_domain_name .. ".wolfram_handlers"

      mock_domain_handler_definitions[handler_module_path_nohandlers] = { not_handlers = "some_data" }

      local good_handler_spy_func = spy.new(function() return "good_output_nohandlers_test" end)
      mock_domain_handler_definitions[handler_module_path_good] = {
        handlers = { good_op_for_this_test = good_handler_spy_func }
      }
      mock_domain_handler_definitions["tungsten.domains.arithmetic.wolfram_handlers"] = nil


      wolfram_backend.reload_handlers()

      local warning_log_found = false
      local expected_log_message = ("Wolfram Backend: Could not load Wolfram handlers for domain '%s'. module '%s' loaded but it did not return a .handlers table."):format(nohandlers_domain_name, handler_module_path_nohandlers)
      for _, call_info in ipairs(logger_notify_spy.calls) do
        local msg, level, opts = call_info.vals[1], call_info.vals[2], call_info.vals[3]
        if msg == expected_log_message and level == tungsten_logger_module.levels.WARN and opts and opts.title == "Tungsten Backend Warning" then
          warning_log_found = true
          break
        end
      end
      assert.is_true(warning_log_found, "Expected WARN log for domain module without .handlers table not found. Logged: " .. simple_inspect(logger_notify_spy.calls))

      local test_ast = { type = "good_op_for_this_test" }
      local result = wolfram_backend.to_string(test_ast)
      assert.spy(good_handler_spy_func).was.called(1)
      assert.are.equal("good_output_nohandlers_test", result)
    end)

    it("should log a warning if a domain module loads as nil (e.g. require returns true, nil via mock_domain_handler_definitions)", function()
      local nil_domain_name = "nil_return_domain"
      test_env.set_plugin_config({ 'domains' }, { nil_domain_name })
      local handler_module_path_nil = "tungsten.domains." .. nil_domain_name .. ".wolfram_handlers"

      mock_domain_handler_definitions[handler_module_path_nil] = nil


      wolfram_backend.reload_handlers()

      local warning_log_found = false
      local expected_log_message = ("Wolfram Backend: Could not load Wolfram handlers for domain '%s'. module '%s' loaded but it did not return a .handlers table."):format(nil_domain_name, handler_module_path_nil)

      for _, call_info in ipairs(logger_notify_spy.calls) do
        local msg, level, opts = call_info.vals[1], call_info.vals[2], call_info.vals[3]
        if msg == expected_log_message and level == tungsten_logger_module.levels.WARN and opts and opts.title == "Tungsten Backend Warning" then
          warning_log_found = true
          break
        end
      end
      assert.is_true(warning_log_found, "Expected WARN log for domain module returning nil not found. Logged: " .. simple_inspect(logger_notify_spy.calls))
    end)
    
  end)
end)
