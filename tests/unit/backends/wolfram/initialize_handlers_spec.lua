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
        return 0 -- Default for any other domain
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
      assert.is_false(found_arithmetic_handler_require, "Did not expect _G.require for 'arithmetic' when not in config.domains")
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
      local custom_handler_module_path = "tungsten.domains." .. custom_domain .. ".wolfram_handlers"
      mock_domain_handler_definitions["tungsten.domains.arithmetic.wolfram_handlers"] = {
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
      assert.is_true(called_modules_map["tungsten.domains.arithmetic.wolfram_handlers"], "Expected require for arithmetic handlers")
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
      -- mock_registry.get_domain_priority is already set up in the outer before_each
      -- to return correct priorities for "low_prio_domain" and "high_prio_domain".
    end)

    it("should use handler from higher priority domain (high_prio domain in config AFTER low_prio)", function()
      mock_config.domains = { "low_prio_domain", "high_prio_domain" }
      mock_config.debug = true -- Ensure debug is on for these specific logs
      mock_domain_handler_definitions["tungsten.domains.low_prio_domain.wolfram_handlers"] = {
        handlers = { [common_node_type] = low_prio_handler_spy }
      }
      mock_domain_handler_definitions["tungsten.domains.high_prio_domain.wolfram_handlers"] = {
        handlers = { [common_node_type] = high_prio_handler_spy }
      }
      -- No need for unrelated_domain here as it doesn't affect the common_node_type

      wolfram_backend.reset_and_reinit_handlers() -- This is where initialization and logging occur
      local result = wolfram_backend.to_string(test_ast) -- This uses the initialized handlers

      local override_log_found = false
      local expected_log_message = ("Wolfram Backend: Handler for node type '%s': high_prio_domain (Prio 200) overrides low_prio_domain (Prio 50)."):format(common_node_type)
      local expected_log_level = mock_logger.levels.DEBUG -- or the specific level from logger.lua
      local expected_title = "Tungsten Backend"

      for _, call_info in ipairs(mock_logger.notify.calls) do
        local call_args = call_info.vals
        if call_args and #call_args >= 3 then -- Ensure message, level, and opts table exist
          local msg = call_args[1]
          local level = call_args[2]
          local opts = call_args[3]
          if type(msg) == "string" and msg == expected_log_message and
             level == expected_log_level and opts and opts.title == expected_title then
            override_log_found = true
            break
          end
        end
      end
      assert.is_true(override_log_found, "Expected debug log for handler override was not found or had incorrect level/title. Logged messages: " .. simple_inspect(mock_logger.notify.calls))

      assert.spy(high_prio_handler_spy).was.called(1)
      assert.spy(low_prio_handler_spy).was_not.called()
      assert.are.equal("high_prio_output", result)
      -- ... rest of your assertions for render call
    end)

    it("should use handler from higher priority domain (high_prio domain in config BEFORE low_prio)", function()
      mock_config.domains = { "high_prio_domain", "low_prio_domain" }
      mock_config.debug = true -- Ensure debug is on
      mock_domain_handler_definitions["tungsten.domains.low_prio_domain.wolfram_handlers"] = {
        handlers = { [common_node_type] = low_prio_handler_spy }
      }
      mock_domain_handler_definitions["tungsten.domains.high_prio_domain.wolfram_handlers"] = {
        handlers = { [common_node_type] = high_prio_handler_spy }
      }

      wolfram_backend.reset_and_reinit_handlers()
      local result = wolfram_backend.to_string(test_ast)

      local not_override_log_found = false
      -- Note: In wolfram.lua, the "NOT overriding" message also uses logger.levels.DEBUG and title "Tungsten Backend"
      local expected_log_message = ("Wolfram Backend: Handler for node type '%s' from low_prio_domain (Prio 50) NOT overriding existing from high_prio_domain (Prio 200)."):format(common_node_type)
      local expected_log_level = mock_logger.levels.DEBUG
      local expected_title = "Tungsten Backend"

      for _, call_info in ipairs(mock_logger.notify.calls) do
        local call_args = call_info.vals
        if call_args and #call_args >= 3 then
          local msg = call_args[1]
          local level = call_args[2]
          local opts = call_args[3]
          if type(msg) == "string" and msg == expected_log_message and
             level == expected_log_level and opts and opts.title == expected_title then
            not_override_log_found = true
            break
          end
        end
      end
      assert.is_true(not_override_log_found, "Expected debug log for 'NOT overriding' was not found or had incorrect level/title. Logged messages: " .. simple_inspect(mock_logger.notify.calls))

      assert.spy(high_prio_handler_spy).was.called(1)
      assert.spy(low_prio_handler_spy).was_not.called()
      assert.are.equal("high_prio_output", result)

      local render_call_history = mock_render.render.calls
      assert.are.equal(1, #render_call_history, "mock_render.render should have been called once")
      if #render_call_history > 0 then
          local first_call_info = render_call_history[1]

          local args_to_render = first_call_info.vals
          -- The error occurs on the next line if args_to_render is nil
          assert.are.same(test_ast, args_to_render[1]) -- This is effectively line 335
          assert.is_table(args_to_render[2], "Second argument to render (H_renderable) should be a table")
          if args_to_render[2] then
              assert.are.same(high_prio_handler_spy, args_to_render[2][common_node_type],
                              "H_renderable should contain the high priority handler for common_node_type")
          end
      end
    end)
  end)
end)
