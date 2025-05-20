package.path = './lua/?.lua;' .. package.path

local spy

local pcall_status, luassert_spy = pcall(require, 'luassert.spy')
if pcall_status then
  spy = luassert_spy
else
  error("Failed to require 'luassert.spy'. Make sure luassert is installed and available in your test environment. Error: " .. tostring(luassert_spy))
end

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


describe("tungsten.backends.wolfram", function()
  local wolfram_backend
  local mock_config
  local mock_registry
  local mock_logger
  local mock_render
  local original_require
  local require_calls
  local mock_domain_handler_definitions

  before_each(function()
    package.loaded['tungsten.backends.wolfram'] = nil
    package.loaded['tungsten.config'] = nil
    package.loaded['tungsten.core.registry'] = nil
    package.loaded['tungsten.util.logger'] = nil
    package.loaded['tungsten.core.render'] = nil
    package.loaded['tungsten.domains.arithmetic.wolfram_handlers'] = nil
    package.loaded['tungsten.domains.custom_domain_one.wolfram_handlers'] = nil
    package.loaded['tungsten.domains.custom_domain_two.wolfram_handlers'] = nil
    package.loaded['tungsten.domains.high_prio_domain.wolfram_handlers'] = nil
    package.loaded['tungsten.domains.low_prio_domain.wolfram_handlers'] = nil
    package.loaded['tungsten.domains.successful_domain.wolfram_handlers'] = nil
    package.loaded['tungsten.domains.missing_domain.wolfram_handlers'] = nil
    package.loaded['tungsten.domains.nohandlers_domain.wolfram_handlers'] = nil
    package.loaded['tungsten.domains.another_good_domain.wolfram_handlers'] = nil
    package.loaded['tungsten.domains.invalid_domain_for_no_handler_test.wolfram_handlers'] = nil


    mock_config = {
      debug = false,
      domains = nil
    }
    package.loaded['tungsten.config'] = mock_config

    mock_registry = {
      get_domain_priority = spy.new(function(domain_name)
        if domain_name == "arithmetic" then return 100 end
        if domain_name == "custom_domain_one" then return 110 end
        if domain_name == "custom_domain_two" then return 90 end
        if domain_name == "high_prio_domain" then return 200 end
        if domain_name == "low_prio_domain" then return 50 end
        if domain_name == "successful_domain" then return 120 end
        if domain_name == "missing_domain" then return 10 end
        if domain_name == "nohandlers_domain" then return 20 end
        if domain_name == "another_good_domain" then return 130 end
        return 0
      end)
    }
    package.loaded['tungsten.core.registry'] = mock_registry

    mock_logger = {
      notify = spy.new(function() end),
      levels = { DEBUG = 1, INFO = 2, WARN = 3, ERROR = 4 }
    }
    package.loaded['tungsten.util.logger'] = mock_logger

    mock_render = {
      render = spy.new(function(ast_node, handlers_table)
        if ast_node and ast_node.type and handlers_table and handlers_table[ast_node.type] then
          local actual_handler_to_call = handlers_table[ast_node.type]
          return actual_handler_to_call(ast_node, function() return "dummy_recursive_call_output" end)
        end
        return "mock_render_FALLBACK_NO_HANDLER_FOR_TYPE"
      end)
    }
    package.loaded['tungsten.core.render'] = mock_render

    mock_domain_handler_definitions = {}

    original_require = _G.require
    require_calls = {}
    _G.require = function(module_path)
      table.insert(require_calls, module_path)

      if package.loaded[module_path] and
         (module_path == 'tungsten.config' or
          module_path == 'tungsten.core.registry' or
          module_path == 'tungsten.util.logger' or
          module_path == 'tungsten.core.render') then
        return package.loaded[module_path]
      end

      if mock_domain_handler_definitions[module_path] then
        if type(mock_domain_handler_definitions[module_path]) == 'function' then
          return mock_domain_handler_definitions[module_path]()
        end
        return mock_domain_handler_definitions[module_path]
      end

      if module_path == "tungsten.domains.arithmetic.wolfram_handlers" and not mock_domain_handler_definitions[module_path] then
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
  end)

  describe("Default Handler Loading (config.domains is nil or empty)", function()
    it("should attempt to load arithmetic handlers if config.domains is nil", function()
      mock_config.domains = nil
      mock_domain_handler_definitions["tungsten.domains.arithmetic.wolfram_handlers"] = {
        handlers = { arith_specific_handler_nil_config = function() end }
      }
      wolfram_backend.reset_and_reinit_handlers()

      local found_arithmetic_handler_require = false
      for _, called_module in ipairs(require_calls) do
        if called_module == "tungsten.domains.arithmetic.wolfram_handlers" then
          found_arithmetic_handler_require = true
          break
        end
      end
      assert.is_true(found_arithmetic_handler_require, "Expected _G.require to be called for 'tungsten.domains.arithmetic.wolfram_handlers'")
      assert.spy(mock_registry.get_domain_priority).was.called_with("arithmetic")
    end)

    it("should attempt to load arithmetic handlers if config.domains is an empty table", function()
      mock_config.domains = {}
      mock_domain_handler_definitions["tungsten.domains.arithmetic.wolfram_handlers"] = {
        handlers = { arith_specific_handler_empty_config = function() end }
      }
      wolfram_backend.reset_and_reinit_handlers()

      local found_arithmetic_handler_require = false
      for _, called_module in ipairs(require_calls) do
        if called_module == "tungsten.domains.arithmetic.wolfram_handlers" then
          found_arithmetic_handler_require = true
          break
        end
      end
      assert.is_true(found_arithmetic_handler_require, "Expected _G.require to be called for 'tungsten.domains.arithmetic.wolfram_handlers'")
      assert.spy(mock_registry.get_domain_priority).was.called_with("arithmetic")
    end)
  end)

  describe("Custom Domain Handler Loading", function()
    it("should attempt to load handlers from a single domain specified in config.domains", function()
      local domain_name = "custom_domain_one"
      local handler_module_path = "tungsten.domains." .. domain_name .. ".wolfram_handlers"
      mock_config.domains = { domain_name }
      mock_domain_handler_definitions[handler_module_path] = {
        handlers = { custom_op_one = function() return "custom_one_output" end }
      }
      mock_domain_handler_definitions["tungsten.domains.arithmetic.wolfram_handlers"] = nil

      wolfram_backend.reset_and_reinit_handlers()

      local found_custom_handler_require = false
      for _, called_module in ipairs(require_calls) do
        if called_module == handler_module_path then
          found_custom_handler_require = true
          break
        end
      end
      assert.is_true(found_custom_handler_require, "Expected _G.require to be called for '" .. handler_module_path .. "'")
      assert.spy(mock_registry.get_domain_priority).was.called_with(domain_name)

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
      mock_config.domains = domain_names
      local handler_module_path_one = "tungsten.domains.custom_domain_one.wolfram_handlers"
      local handler_module_path_two = "tungsten.domains.custom_domain_two.wolfram_handlers"

      mock_domain_handler_definitions[handler_module_path_one] = {
        handlers = { custom_op_one = function() end }
      }
      mock_domain_handler_definitions[handler_module_path_two] = {
        handlers = { custom_op_two = function() end }
      }
      mock_domain_handler_definitions["tungsten.domains.arithmetic.wolfram_handlers"] = nil

      wolfram_backend.reset_and_reinit_handlers()

      local require_calls_for_custom_domains = {}
      for _, called_module in ipairs(require_calls) do
        if called_module == handler_module_path_one or called_module == handler_module_path_two then
          require_calls_for_custom_domains[called_module] = true
        end
      end
      assert.is_true(require_calls_for_custom_domains[handler_module_path_one], "Expected _G.require for '" .. handler_module_path_one .. "'")
      assert.is_true(require_calls_for_custom_domains[handler_module_path_two], "Expected _G.require for '" .. handler_module_path_two .. "'")
      assert.spy(mock_registry.get_domain_priority).was.called_with("custom_domain_one")
      assert.spy(mock_registry.get_domain_priority).was.called_with("custom_domain_two")
    end)

     it("should also load arithmetic handlers if 'arithmetic' is explicitly in config.domains along with custom domains", function()
      local custom_domain = "custom_domain_one"
      mock_config.domains = { "arithmetic", custom_domain }

      local arithmetic_handler_module_path = "tungsten.domains.arithmetic.wolfram_handlers"
      local custom_handler_module_path = "tungsten.domains." .. custom_domain .. ".wolfram_handlers"

      mock_domain_handler_definitions[arithmetic_handler_module_path] = {
        handlers = { arith_op = function() end }
      }
      mock_domain_handler_definitions[custom_handler_module_path] = {
        handlers = { custom_op = function() end }
      }

      wolfram_backend.reset_and_reinit_handlers()

      local called_modules_map = {}
      for _, called_module in ipairs(require_calls) do
        called_modules_map[called_module] = true
      end

      assert.is_true(called_modules_map[arithmetic_handler_module_path], "Expected require for arithmetic handlers")
      assert.is_true(called_modules_map[custom_handler_module_path], "Expected require for custom_domain_one handlers")
      assert.spy(mock_registry.get_domain_priority).was.called_with("arithmetic")
      assert.spy(mock_registry.get_domain_priority).was.called_with(custom_domain)
    end)
  end)

  describe("Handler Prioritization and Overriding", function()
    local low_prio_handler_spy, high_prio_handler_spy
    local common_node_type = "common_node"
    local test_ast

    before_each(function()
      mock_config.debug = true
      low_prio_handler_spy = spy.new(function() return "low_prio_output" end)
      high_prio_handler_spy = spy.new(function() return "high_prio_output" end)
      test_ast = { type = common_node_type, data = "some_data" }
    end)

    it("should use handler from higher priority domain (high_prio domain in config AFTER low_prio)", function()
      mock_config.domains = { "low_prio_domain", "high_prio_domain" }

      local low_prio_path = "tungsten.domains.low_prio_domain.wolfram_handlers"
      local high_prio_path = "tungsten.domains.high_prio_domain.wolfram_handlers"

      mock_domain_handler_definitions[low_prio_path] = {
        handlers = { [common_node_type] = low_prio_handler_spy, unrelated_low = function() end }
      }
      mock_domain_handler_definitions[high_prio_path] = {
        handlers = { [common_node_type] = high_prio_handler_spy, unrelated_high = function() end }
      }
      mock_domain_handler_definitions["tungsten.domains.arithmetic.wolfram_handlers"] = nil

      wolfram_backend.reset_and_reinit_handlers()
      local result = wolfram_backend.to_string(test_ast)

      local override_log_found = false
      local expected_log_message = ("Wolfram Backend: Handler for node type '%s': high_prio_domain (Prio 200) overrides low_prio_domain (Prio 50)."):format(common_node_type)
      local expected_log_level = mock_logger.levels.DEBUG
      local expected_title = "Tungsten Backend"

      for _, call_info in ipairs(mock_logger.notify.calls) do
        local call_args = call_info.vals
        if call_args and #call_args >= 3 then
          local msg, level, opts = call_args[1], call_args[2], call_args[3]
          if type(msg) == "string" and msg == expected_log_message and level == expected_log_level and opts and opts.title == expected_title then
            override_log_found = true
            break
          end
        end
      end
      assert.is_true(override_log_found, "Expected debug log for handler override was not found. Logged: " .. simple_inspect(mock_logger.notify.calls))

      assert.spy(high_prio_handler_spy).was.called(1)
      assert.spy(low_prio_handler_spy).was_not.called()
      assert.are.equal("high_prio_output", result)

      local render_calls = mock_render.render.calls
      assert.are.equal(1, #render_calls)
      assert.are.same(test_ast, render_calls[1].vals[1])
      assert.is_table(render_calls[1].vals[2])
      assert.are.same(high_prio_handler_spy, render_calls[1].vals[2][common_node_type])
      assert.is_function(render_calls[1].vals[2]["unrelated_low"])
      assert.is_function(render_calls[1].vals[2]["unrelated_high"])
    end)

    it("should use handler from higher priority domain (high_prio domain in config BEFORE low_prio - testing 'NOT overriding' log)", function()
      mock_config.domains = { "high_prio_domain", "low_prio_domain" }
       mock_config.debug = true

      local low_prio_path = "tungsten.domains.low_prio_domain.wolfram_handlers"
      local high_prio_path = "tungsten.domains.high_prio_domain.wolfram_handlers"

      mock_domain_handler_definitions[low_prio_path] = {
        handlers = { [common_node_type] = low_prio_handler_spy }
      }
      mock_domain_handler_definitions[high_prio_path] = {
        handlers = { [common_node_type] = high_prio_handler_spy }
      }
      mock_domain_handler_definitions["tungsten.domains.arithmetic.wolfram_handlers"] = nil

      wolfram_backend.reset_and_reinit_handlers()
      local result = wolfram_backend.to_string(test_ast)

      local not_override_log_found = false
      local expected_log_message = ("Wolfram Backend: Handler for node type '%s' from low_prio_domain (Prio 50) NOT overriding existing from high_prio_domain (Prio 200)."):format(common_node_type)
      local expected_log_level = mock_logger.levels.DEBUG
      local expected_title = "Tungsten Backend"

      for _, call_info in ipairs(mock_logger.notify.calls) do
        local call_args = call_info.vals
        if call_args and #call_args >= 3 then
          local msg, level, opts = call_args[1], call_args[2], call_args[3]
          if type(msg) == "string" and msg == expected_log_message and level == expected_log_level and opts and opts.title == expected_title then
            not_override_log_found = true
            break
          end
        end
      end
      assert.is_true(not_override_log_found, "Expected debug log for 'NOT overriding' was not found. Logged: " .. simple_inspect(mock_logger.notify.calls))

      assert.spy(high_prio_handler_spy).was.called(1)
      assert.spy(low_prio_handler_spy).was_not.called()
      assert.are.equal("high_prio_output", result)
    end)

    it("should log a warning and pick one for same priority conflict", function()
        mock_config.domains = { "custom_domain_one", "high_prio_domain", "custom_domain_two" }
        mock_config.debug = true

        local original_get_priority_spy = mock_registry.get_domain_priority

        mock_registry.get_domain_priority = spy.new(function(domain_name)
            if domain_name == "custom_domain_one" then return 200 end
            if domain_name == "high_prio_domain" then return 200 end
            if domain_name == "custom_domain_two" then return 90 end
            if type(original_get_priority_spy.target_function) == 'function' then
                return original_get_priority_spy.target_function(domain_name)
            elseif original_get_priority_spy.calls then
                 for _, call_info in ipairs(original_get_priority_spy.calls) do
                    if call_info.params[1] == domain_name then return call_info.returns[1] end
                 end
            end
            if domain_name == "arithmetic" then return 100 end
            return 0
        end)
        package.loaded['tungsten.core.registry'] = mock_registry

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

        wolfram_backend.reset_and_reinit_handlers()
        local result = wolfram_backend.to_string(test_ast)

        local conflict_log_found = false
        local expected_log_message = ("Wolfram Backend: Handler for node type '%s': CONFLICT - %s and %s have same priority (%d). '%s' takes precedence (due to processing order). Consider adjusting priorities."):format(
            common_node_type,
            "high_prio_domain",
            "custom_domain_one",
            200,
            "high_prio_domain"
        )
        local expected_log_level = mock_logger.levels.WARN
        local expected_title = "Tungsten Backend Warning"

        for _, call_info in ipairs(mock_logger.notify.calls) do
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
        assert.is_true(conflict_log_found, "Expected WARN log for handler conflict was not found or was incorrect. \nExpected: [" .. expected_log_message .. "]\nActual Logged Messages: " .. simple_inspect(mock_logger.notify.calls))

        assert.spy(handler_spy_high_prio).was.called(1)
        assert.spy(handler_spy_custom_one).was_not.called()
        assert.are.equal("high_prio_output", result)

        mock_registry.get_domain_priority = original_get_priority_spy
        package.loaded['tungsten.core.registry'] = mock_registry
    end)
  end)

  describe("Handling of Domain Modules", function()
    it("should successfully load and process handlers from a correctly defined domain module", function()
      local domain_name = "successful_domain"
      local handler_module_path = "tungsten.domains." .. domain_name .. ".wolfram_handlers"
      mock_config.domains = { domain_name }
      mock_config.debug = true

      local success_handler_spy = spy.new(function() return "success_domain_output" end)
      mock_domain_handler_definitions[handler_module_path] = {
        handlers = { specific_op = success_handler_spy }
      }
      mock_domain_handler_definitions["tungsten.domains.arithmetic.wolfram_handlers"] = nil

      wolfram_backend.reset_and_reinit_handlers()

      local found_require = false
      for _, called_module in ipairs(require_calls) do
        if called_module == handler_module_path then
          found_require = true
          break
        end
      end
      assert.is_true(found_require, "Expected _G.require to be called for '" .. handler_module_path .. "'")
      assert.spy(mock_registry.get_domain_priority).was.called_with(domain_name)

      local success_log_found = false
      local expected_log_message = ("Wolfram Backend: Successfully loaded handlers module from %s for domain %s (Priority: %d)"):format(handler_module_path, domain_name, 120)
      for _, call_info in ipairs(mock_logger.notify.calls) do
        if call_info.vals[1] == expected_log_message and call_info.vals[2] == mock_logger.levels.DEBUG then
          success_log_found = true
          break
        end
      end
      assert.is_true(success_log_found, "Expected debug log for successful handler loading not found. Logged: " .. simple_inspect(mock_logger.notify.calls))

      local test_ast = { type = "specific_op" }
      local result = wolfram_backend.to_string(test_ast)
      assert.spy(success_handler_spy).was.called(1)
      assert.are.equal("success_domain_output", result)
    end)

    it("should log a warning and continue if a domain module is missing", function()
      local missing_domain_name = "missing_domain"
      local another_good_domain_name = "another_good_domain"
      local handler_module_path_missing = "tungsten.domains." .. missing_domain_name .. ".wolfram_handlers"
      local handler_module_path_good = "tungsten.domains." .. another_good_domain_name .. ".wolfram_handlers"

      mock_config.domains = { missing_domain_name, another_good_domain_name }

      _G.require = function(module_path)
          table.insert(require_calls, module_path)
          if module_path == handler_module_path_missing then
              error("Simulated error: module '" .. module_path .. "' not found.")
          elseif mock_domain_handler_definitions[module_path] then
              return mock_domain_handler_definitions[module_path]
          elseif package.loaded[module_path] and
             (module_path == 'tungsten.config' or
              module_path == 'tungsten.core.registry' or
              module_path == 'tungsten.util.logger' or
              module_path == 'tungsten.core.render') then
            return package.loaded[module_path]
          end
          return original_require(module_path)
      end

      local good_handler_spy = spy.new(function() return "good_output" end)
      mock_domain_handler_definitions[handler_module_path_good] = {
        handlers = { good_op = good_handler_spy }
      }
      mock_domain_handler_definitions["tungsten.domains.arithmetic.wolfram_handlers"] = nil

      wolfram_backend.reset_and_reinit_handlers()

      local warning_log_found = false
      local expected_error_detail = "Simulated error: module '" .. handler_module_path_missing .. "' not found."
      local expected_log_message_pattern = ("Wolfram Backend: Could not load Wolfram handlers for domain '%s'. Failed to load module '%s': "):format(missing_domain_name, handler_module_path_missing)

      for _, call_info in ipairs(mock_logger.notify.calls) do
        local msg, level, opts = call_info.vals[1], call_info.vals[2], call_info.vals[3]
        if type(msg) == "string" and string.find(msg, expected_log_message_pattern, 1, true) and string.find(msg, expected_error_detail, 1, true) and
           level == mock_logger.levels.WARN and opts and opts.title == "Tungsten Backend Warning" then
          warning_log_found = true
          break
        end
      end
      assert.is_true(warning_log_found, "Expected WARN log for missing domain module not found or incorrect. Logged: " .. simple_inspect(mock_logger.notify.calls))

      local test_ast = { type = "good_op" }
      local result = wolfram_backend.to_string(test_ast)
      assert.spy(good_handler_spy).was.called(1)
      assert.are.equal("good_output", result)
    end)

    it("should log a warning if a domain module is loaded but does not have a .handlers table", function()
      local nohandlers_domain_name = "nohandlers_domain"
      local another_good_domain_name = "another_good_domain_for_nohandlers_test"
      mock_config.domains = { nohandlers_domain_name, another_good_domain_name }

      local handler_module_path_nohandlers = "tungsten.domains." .. nohandlers_domain_name .. ".wolfram_handlers"
      local handler_module_path_good = "tungsten.domains." .. another_good_domain_name .. ".wolfram_handlers"

      mock_domain_handler_definitions[handler_module_path_nohandlers] = { not_handlers = "some_data" }

      local good_handler_spy = spy.new(function() return "good_output_nohandlers_test" end)
      mock_domain_handler_definitions[handler_module_path_good] = {
        handlers = { good_op_for_this_test = good_handler_spy }
      }
      mock_domain_handler_definitions["tungsten.domains.arithmetic.wolfram_handlers"] = nil


        local original_get_priority = mock_registry.get_domain_priority
        mock_registry.get_domain_priority = spy.new(function(domain_name)
            if domain_name == nohandlers_domain_name then return 30 end
            if domain_name == another_good_domain_name then return 40 end
            return original_get_priority(domain_name)
        end)
        package.loaded['tungsten.core.registry'] = mock_registry

      wolfram_backend.reset_and_reinit_handlers()

      local warning_log_found = false
      local expected_log_message = ("Wolfram Backend: Could not load Wolfram handlers for domain '%s'. module '%s' loaded but it did not return a .handlers table."):format(nohandlers_domain_name, handler_module_path_nohandlers)
      for _, call_info in ipairs(mock_logger.notify.calls) do
        local msg, level, opts = call_info.vals[1], call_info.vals[2], call_info.vals[3]
        if msg == expected_log_message and level == mock_logger.levels.WARN and opts and opts.title == "Tungsten Backend Warning" then
          warning_log_found = true
          break
        end
      end
      assert.is_true(warning_log_found, "Expected WARN log for domain module without .handlers table not found. Logged: " .. simple_inspect(mock_logger.notify.calls))

      local test_ast = { type = "good_op_for_this_test" }
      local result = wolfram_backend.to_string(test_ast)
      assert.spy(good_handler_spy).was.called(1)
      assert.are.equal("good_output_nohandlers_test", result)

      mock_registry.get_domain_priority = original_get_priority
      package.loaded['tungsten.core.registry'] = mock_registry
    end)

     it("should log a warning if a domain module loads as nil (e.g. require returns true, nil)", function()
      local nil_domain_name = "nil_return_domain"
      mock_config.domains = { nil_domain_name }
      local handler_module_path_nil = "tungsten.domains." .. nil_domain_name .. ".wolfram_handlers"

      mock_domain_handler_definitions[handler_module_path_nil] = nil 
      local original_get_priority = mock_registry.get_domain_priority
      mock_registry.get_domain_priority = spy.new(function(domain_name_arg)
          if domain_name_arg == nil_domain_name then return 25 end
          return original_get_priority(domain_name_arg)
      end)
      package.loaded['tungsten.core.registry'] = mock_registry

      wolfram_backend.reset_and_reinit_handlers()

      local warning_log_found = false
      local expected_log_message = ("Wolfram Backend: Could not load Wolfram handlers for domain '%s'. module '%s' loaded but it did not return a .handlers table."):format(nil_domain_name, handler_module_path_nil)
      for _, call_info in ipairs(mock_logger.notify.calls) do
        local msg, level, opts = call_info.vals[1], call_info.vals[2], call_info.vals[3]
        if msg == expected_log_message and level == mock_logger.levels.WARN and opts and opts.title == "Tungsten Backend Warning" then
          warning_log_found = true
          break
        end
      end
      assert.is_true(warning_log_found, "Expected WARN log for domain module returning nil not found. Logged: " .. simple_inspect(mock_logger.notify.calls))
      
      mock_registry.get_domain_priority = original_get_priority
      package.loaded['tungsten.core.registry'] = mock_registry
    end)
    it("should log an ERROR if no domain handlers are successfully loaded", function()
      mock_config.domains = { "non_existent_domain_one", "non_existent_domain_two" }
      mock_config.debug = false

      mock_domain_handler_definitions["tungsten.domains.arithmetic.wolfram_handlers"] = nil

      wolfram_backend.reset_and_reinit_handlers()

      local error_log_found = false
      local expected_log_message = "Wolfram Backend: No Wolfram handlers were loaded. AST to string conversion will likely fail or produce incorrect results."
      local expected_log_level = mock_logger.levels.ERROR
      local expected_title = "Tungsten Backend Error"

      for _, call_info in ipairs(mock_logger.notify.calls) do
        local msg, level, opts = call_info.vals[1], call_info.vals[2], call_info.vals[3]
        if msg == expected_log_message and level == expected_log_level and opts and opts.title == expected_title then
          error_log_found = true
          break
        end
      end
      assert.is_true(error_log_found, "Expected ERROR log when no handlers are loaded was not found. Logged: " .. simple_inspect(mock_logger.notify.calls))

      local test_ast_node = { type = "some_node_type" }
      wolfram_backend.to_string(test_ast_node)

      local to_string_error_log_found = false
      local expected_to_string_error_message = "Wolfram Backend: No Wolfram handlers available when to_string was called."
      for _, call_info in ipairs(mock_logger.notify.calls) do
        local msg, level, opts = call_info.vals[1], call_info.vals[2], call_info.vals[3]
        if msg == expected_to_string_error_message and level == mock_logger.levels.ERROR and opts and opts.title == expected_title then
          to_string_error_log_found = true
          break
        end
      end
      assert.is_true(to_string_error_log_found, "Expected ERROR log from to_string due to no handlers not found. Logged: " .. simple_inspect(mock_logger.notify.calls))
    end)
  end)
end)
