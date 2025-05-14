-- At the very top of your tests/unit/backends/wolfram_spec.lua file:
-- 1. Adjust package.path so Lua can find your project's modules.
-- This assumes your 'lua' directory is at the project root.
package.path = './lua/?.lua;' .. package.path

-- 2. Require 'luassert.spy'
local spy

local pcall_status, luassert_spy = pcall(require, 'luassert.spy')
if pcall_status then
  spy = luassert_spy
else
  error("Failed to require 'luassert.spy'. Make sure luassert is installed and available in your test environment. Error: " .. tostring(luassert_spy))
end

-- Helper function to serialize a table for debugging (simple version)
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
  local mock_render -- For tungsten.core.render
  local original_require
  local require_calls
  local mock_domain_handler_definitions

  before_each(function()
    -- 1. Clean up previously loaded modules to ensure fresh state
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
    -- Add new mock domain paths for new tests
    package.loaded['tungsten.domains.successful_domain.wolfram_handlers'] = nil
    package.loaded['tungsten.domains.missing_domain.wolfram_handlers'] = nil
    package.loaded['tungsten.domains.nohandlers_domain.wolfram_handlers'] = nil
    package.loaded['tungsten.domains.another_good_domain.wolfram_handlers'] = nil


    -- 2. Setup mocks for direct dependencies of wolfram.lua
    mock_config = {
      debug = false,
      domains = nil -- Default to nil, tests can override
    }
    package.loaded['tungsten.config'] = mock_config

    mock_registry = {
      get_domain_priority = spy.new(function(domain_name)
        if domain_name == "arithmetic" then return 100 end
        if domain_name == "custom_domain_one" then return 110 end
        if domain_name == "custom_domain_two" then return 90 end
        if domain_name == "high_prio_domain" then return 200 end -- Used in prioritization tests
        if domain_name == "low_prio_domain" then return 50 end   -- Used in prioritization tests
        if domain_name == "successful_domain" then return 120 end
        if domain_name == "missing_domain" then return 10 end -- Priority doesn't matter much if it's missing
        if domain_name == "nohandlers_domain" then return 20 end
        if domain_name == "another_good_domain" then return 130 end
        return 0 -- Default for any other domain
      end)
    }
    package.loaded['tungsten.core.registry'] = mock_registry

    mock_logger = {
      notify = spy.new(function() end),
      levels = { DEBUG = 1, INFO = 2, WARN = 3, ERROR = 4 } -- Ensure levels match your logger.lua
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

      -- Allow direct dependencies of wolfram.lua to be loaded normally if not specifically mocked
      if package.loaded[module_path] and
         (module_path == 'tungsten.config' or
          module_path == 'tungsten.core.registry' or
          module_path == 'tungsten.util.logger' or
          module_path == 'tungsten.core.render') then
        return package.loaded[module_path]
      end

      -- Return mocked domain handler definitions if available
      if mock_domain_handler_definitions[module_path] then
        -- If the definition is a function, call it to simulate pcall behavior for require
        if type(mock_domain_handler_definitions[module_path]) == 'function' then
          return mock_domain_handler_definitions[module_path]()
        end
        return mock_domain_handler_definitions[module_path]
      end
      
      -- Fallback for arithmetic if not specifically mocked for a test
      if module_path == "tungsten.domains.arithmetic.wolfram_handlers" and not mock_domain_handler_definitions[module_path] then
        return { handlers = { mock_arith_op_handler_fallback = function() end } }
      end

      -- Default behavior for other domain handlers not explicitly mocked: simulate module not found for pcall
      -- This is crucial for testing missing modules.
      if string.find(module_path, "tungsten.domains%.[^%.]+%.wolfram_handlers") then
         -- Simulate pcall behavior: for a missing module, `require` would error,
         -- so `pcall(require, ...)` would return `false, error_message`.
         -- The wolfram.lua uses `pcall`, so we need to simulate what `pcall` returns.
         -- For simplicity in the mock, if it's not in mock_domain_handler_definitions,
         -- we'll have the pcall in wolfram.lua handle it by returning nil from this mock require,
         -- which pcall will then treat as `true, nil`.
         -- To explicitly test a *failed* require (pcall returns false),
         -- the test itself should set up mock_domain_handler_definitions[module_path] to a function
         -- that returns nil and an error message, or directly error.
         -- For now, returning nil means the module loaded but was empty or didn't conform.
         -- For the "Missing Domain Module" test, we'll explicitly make it return as if pcall failed.
         return nil 
      end

      -- Fallback to original require for any other modules (like luassert itself)
      return original_require(module_path)
    end

    -- Require the module under test AFTER all mocks are set up
    wolfram_backend = _G.require("tungsten.backends.wolfram")
  end)

  after_each(function()
    _G.require = original_require -- Restore original require
  end)

  describe("Default Handler Loading (config.domains is nil or empty)", function()
    it("should attempt to load arithmetic handlers if config.domains is nil", function()
      mock_config.domains = nil -- Explicitly set for this test case
      -- Mock the arithmetic handlers module to ensure it's "found"
      mock_domain_handler_definitions["tungsten.domains.arithmetic.wolfram_handlers"] = {
        handlers = { arith_specific_handler_nil_config = function() end }
      }
      wolfram_backend.reset_and_reinit_handlers() -- Trigger initialization

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
      mock_config.domains = {} -- Explicitly set for this test case
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
      -- Ensure arithmetic is NOT loaded by default if not in config.domains explicitly
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

      -- Verify arithmetic was NOT loaded
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
      mock_domain_handler_definitions["tungsten.domains.arithmetic.wolfram_handlers"] = nil -- Explicitly do not load arithmetic

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
      mock_config.domains = { "arithmetic", custom_domain } -- Arithmetic is explicitly included
      
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
      mock_config.debug = true -- Enable debug for logging checks in these tests
      low_prio_handler_spy = spy.new(function() return "low_prio_output" end)
      high_prio_handler_spy = spy.new(function() return "high_prio_output" end)
      test_ast = { type = common_node_type, data = "some_data" }
      -- Priorities for "low_prio_domain" (50) and "high_prio_domain" (200) are set in the outer before_each
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

      -- Check for the override log message
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
      assert.is_function(render_calls[1].vals[2]["unrelated_low"]) -- Should still exist
      assert.is_function(render_calls[1].vals[2]["unrelated_high"]) -- Should still exist
    end)

    it("should use handler from higher priority domain (high_prio domain in config BEFORE low_prio - testing 'NOT overriding' log)", function()
      mock_config.domains = { "high_prio_domain", "low_prio_domain" } -- Order changed
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
      
      -- Check for the "NOT overriding" log message
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
        mock_config.debug = true -- To see all relevant logs during debugging if needed

        -- Save the original spy for restoration
        local original_get_priority_spy = mock_registry.get_domain_priority

        mock_registry.get_domain_priority = spy.new(function(domain_name)
            if domain_name == "custom_domain_one" then return 200 end
            if domain_name == "high_prio_domain" then return 200 end
            if domain_name == "custom_domain_two" then return 90 end
            -- Fallback for any other domain that might be queried by the system
            if type(original_get_priority_spy.target_function) == 'function' then
                return original_get_priority_spy.target_function(domain_name)
            elseif original_get_priority_spy.calls then -- Check if it's a spy
                 for _, call_info in ipairs(original_get_priority_spy.calls) do
                    if call_info.params[1] == domain_name then return call_info.returns[1] end
                 end
            end
            if domain_name == "arithmetic" then return 100 end -- Default for arithmetic if not spied
            return 0 -- Default
        end)
        package.loaded['tungsten.core.registry'] = mock_registry

        local handler_spy_custom_one = spy.new(function() return "custom_one_output" end)
        local handler_spy_high_prio = spy.new(function() return "high_prio_output" end)

        -- common_node_type is defined in the parent describe's before_each as "common_node"
        -- test_ast is also defined there using common_node_type

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
        local result = wolfram_backend.to_string(test_ast) -- test_ast uses common_node_type

        local conflict_log_found = false
        -- This is the deterministically expected log message
        local expected_log_message = ("Wolfram Backend: Handler for node type '%s': CONFLICT - %s and %s have same priority (%d). '%s' takes precedence (due to processing order). Consider adjusting priorities."):format(
            common_node_type,   -- Should be "common_node"
            "high_prio_domain", -- The domain currently being processed that causes the conflict
            "custom_domain_one",-- The domain already in the HANDLERS_STORE
            200,                -- The priority
            "high_prio_domain"  -- The domain that wins (the one currently being processed)
        )
        local expected_log_level = mock_logger.levels.WARN
        local expected_title = "Tungsten Backend Warning"

        for _, call_info in ipairs(mock_logger.notify.calls) do
            local call_args = call_info.vals
            if call_args and #call_args >= 3 then
                local msg, level, opts = call_args[1], call_args[2], call_args[3]
                -- Use direct string comparison instead of string.match
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

  -- NEW Describe block for Handling of Domain Modules
  describe("Handling of Domain Modules", function()
    it("should successfully load and process handlers from a correctly defined domain module", function()
      local domain_name = "successful_domain"
      local handler_module_path = "tungsten.domains." .. domain_name .. ".wolfram_handlers"
      mock_config.domains = { domain_name }
      mock_config.debug = true -- Enable debug for more detailed logs

      local success_handler_spy = spy.new(function() return "success_domain_output" end)
      mock_domain_handler_definitions[handler_module_path] = {
        handlers = { specific_op = success_handler_spy }
      }
      mock_domain_handler_definitions["tungsten.domains.arithmetic.wolfram_handlers"] = nil -- Avoid default loading

      wolfram_backend.reset_and_reinit_handlers()

      -- Verify require was called
      local found_require = false
      for _, called_module in ipairs(require_calls) do
        if called_module == handler_module_path then
          found_require = true
          break
        end
      end
      assert.is_true(found_require, "Expected _G.require to be called for '" .. handler_module_path .. "'")
      assert.spy(mock_registry.get_domain_priority).was.called_with(domain_name)

      -- Verify logger.notify was called with success message (if debug is on)
      local success_log_found = false
      local expected_log_message = ("Wolfram Backend: Successfully loaded handlers module from %s for domain %s (Priority: %d)"):format(handler_module_path, domain_name, 120) -- Prio 120 from mock_registry
      for _, call_info in ipairs(mock_logger.notify.calls) do
        if call_info.vals[1] == expected_log_message and call_info.vals[2] == mock_logger.levels.DEBUG then
          success_log_found = true
          break
        end
      end
      assert.is_true(success_log_found, "Expected debug log for successful handler loading not found. Logged: " .. simple_inspect(mock_logger.notify.calls))

      -- Verify the handler is used
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

      -- Simulate require failing for the missing domain
      -- The pcall in wolfram.lua will catch this.
      -- Our mock _G.require, if a module is not in mock_domain_handler_definitions,
      -- and matches the pattern, already returns nil, which pcall(require,...) turns into true, nil.
      -- To make pcall(require,...) return `false, "error message"`, we need to make the mock `require` itself error.
      -- For simplicity in this mock setup, we'll make the mock_domain_handler_definitions entry a function that errors.
      -- However, the wolfram.lua module's pcall expects `require` to be the function that might error.
      -- Let's adjust the main mock_require to better simulate this.
      -- For this specific test, we'll make the entry for the missing module path in mock_domain_handler_definitions
      -- a function that, when called by the mocked `_G.require`, returns nil.
      -- The `pcall` in `wolfram.lua` will see this as `ok=true, domain_module=nil`.
      -- This actually tests the "module loaded but was nil" case.
      -- To test "pcall(require,...) -> false, err", we need a way for the mock require to error for 'missing_domain'.

      -- Let's refine the _G.require mock to allow error simulation for specific modules.
      -- For this test, we set it up so that pcall in wolfram.lua returns false for missing_domain.
      -- The mock_domain_handler_definitions can store a special value or function for this.
      -- For now, let the default behavior of the mock _G.require handle it if the module_path is not in mock_domain_handler_definitions
      -- and it matches the pattern. It returns nil. The `pcall` in `initialize_handlers` would get `true, nil`. This is not what we want for a "module not found" error.

      -- We need to ensure our mock `_G.require` actually *errors* for the missing module path
      -- so that `pcall` in `initialize_handlers` returns `ok = false`.
      _G.require = function(module_path)
          table.insert(require_calls, module_path)
          if module_path == handler_module_path_missing then
              error("Simulated error: module '" .. module_path .. "' not found.") -- This makes pcall return false
          elseif mock_domain_handler_definitions[module_path] then
              return mock_domain_handler_definitions[module_path]
          elseif package.loaded[module_path] and
             (module_path == 'tungsten.config' or
              module_path == 'tungsten.core.registry' or
              module_path == 'tungsten.util.logger' or
              module_path == 'tungsten.core.render') then
            return package.loaded[module_path]
          end
          return original_require(module_path) -- Fallback for other modules
      end
      
      local good_handler_spy = spy.new(function() return "good_output" end)
      mock_domain_handler_definitions[handler_module_path_good] = {
        handlers = { good_op = good_handler_spy }
      }
      mock_domain_handler_definitions["tungsten.domains.arithmetic.wolfram_handlers"] = nil

      wolfram_backend.reset_and_reinit_handlers()

      -- Verify warning log for missing_domain
      local warning_log_found = false
      -- The error message from our mocked require will be part of the log
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

      -- Verify the good domain was still loaded and its handler works
      local test_ast = { type = "good_op" }
      local result = wolfram_backend.to_string(test_ast)
      assert.spy(good_handler_spy).was.called(1)
      assert.are.equal("good_output", result)
    end)

    it("should log a warning if a domain module is loaded but does not have a .handlers table", function()
      local nohandlers_domain_name = "nohandlers_domain"
      local another_good_domain_name = "another_good_domain_for_nohandlers_test" -- Use a unique name
      mock_config.domains = { nohandlers_domain_name, another_good_domain_name }
      
      local handler_module_path_nohandlers = "tungsten.domains." .. nohandlers_domain_name .. ".wolfram_handlers"
      local handler_module_path_good = "tungsten.domains." .. another_good_domain_name .. ".wolfram_handlers"

      -- Mock for the domain that returns a table, but not one with a 'handlers' key
      mock_domain_handler_definitions[handler_module_path_nohandlers] = { not_handlers = "some_data" } -- No .handlers table
      
      local good_handler_spy = spy.new(function() return "good_output_nohandlers_test" end)
      mock_domain_handler_definitions[handler_module_path_good] = {
        handlers = { good_op_for_this_test = good_handler_spy }
      }
      -- Clear arithmetic mock if not explicitly needed
      mock_domain_handler_definitions["tungsten.domains.arithmetic.wolfram_handlers"] = nil


      -- Need to make sure priorities are returned for these new domains
        local original_get_priority = mock_registry.get_domain_priority
        mock_registry.get_domain_priority = spy.new(function(domain_name)
            if domain_name == nohandlers_domain_name then return 30 end
            if domain_name == another_good_domain_name then return 40 end
            return original_get_priority(domain_name)
        end)
        package.loaded['tungsten.core.registry'] = mock_registry

      wolfram_backend.reset_and_reinit_handlers()

      -- Verify warning log for nohandlers_domain
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

      -- Verify the other good domain was still loaded and its handler works
      local test_ast = { type = "good_op_for_this_test" }
      local result = wolfram_backend.to_string(test_ast)
      assert.spy(good_handler_spy).was.called(1)
      assert.are.equal("good_output_nohandlers_test", result)

      -- Restore original mock_registry.get_domain_priority
      mock_registry.get_domain_priority = original_get_priority
      package.loaded['tungsten.core.registry'] = mock_registry
    end)

     it("should log a warning if a domain module loads as nil (e.g. require returns true, nil)", function()
      local nil_domain_name = "nil_return_domain"
      mock_config.domains = { nil_domain_name }
      local handler_module_path_nil = "tungsten.domains." .. nil_domain_name .. ".wolfram_handlers"

      -- Mock require to return nil for this specific module (pcall would make this true, nil)
      mock_domain_handler_definitions[handler_module_path_nil] = nil 
      -- Ensure its priority is available
      local original_get_priority = mock_registry.get_domain_priority
      mock_registry.get_domain_priority = spy.new(function(domain_name_arg)
          if domain_name_arg == nil_domain_name then return 25 end
          return original_get_priority(domain_name_arg)
      end)
      package.loaded['tungsten.core.registry'] = mock_registry

      wolfram_backend.reset_and_reinit_handlers()

      local warning_log_found = false
      -- This scenario also results in the "did not return a .handlers table" message because domain_module is nil
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
  end)
end)
