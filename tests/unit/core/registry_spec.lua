-- tests/unit/core/registry_spec.lua
-- Unit tests for the Tungsten grammar and domain registry.
---------------------------------------------------------------------

local spy = require 'luassert.spy'
local match = require 'luassert.match'

local mock_pattern_mt = {}
local function create_mock_pattern(name)
  assert(type(name) == "string", "Mock pattern name must be a string for debugging: " .. tostring(name))
  local p = { _name = name, is_mock_pattern = true }
  if getmetatable(p) ~= mock_pattern_mt then
    setmetatable(p, mock_pattern_mt)
  end
  return p
end

mock_pattern_mt.__add = function(lhs, rhs)
  local l_name_str = (type(lhs) == "table" and lhs._name) or tostring(lhs)
  local r_name_str = (type(rhs) == "table" and rhs._name) or tostring(rhs)
  if not l_name_str or not r_name_str then
      error("Attempt to add mock patterns with nil or non-string names: lhs=" .. tostring(l_name_str) .. ", rhs=" .. tostring(r_name_str))
  end
  return create_mock_pattern("(" .. l_name_str .. " + " .. r_name_str .. ")")
end

mock_pattern_mt.__mul = function(lhs, rhs)
  local l_name_str = (type(lhs) == "table" and lhs._name) or tostring(lhs)
  local r_name_str = (type(rhs) == "table" and rhs._name) or tostring(rhs)
    if not l_name_str or not r_name_str then
      error("Attempt to multiply mock patterns with nil or non-string names: lhs=" .. tostring(l_name_str) .. ", rhs=" .. tostring(r_name_str))
  end
  return create_mock_pattern("(" .. l_name_str .. " * " .. r_name_str .. ")")
end
mock_pattern_mt.__tostring = function(self) return self._name or "unnamed_mock_pattern" end


describe("tungsten.core.registry", function()
  local registry_module

  local mock_lpeg_module
  local mock_tokenizer_module
  local mock_logger_module
  local mock_config_module

  local mock_lpeg_P_spy
  local mock_lpeg_V_spy
  local mock_logger_notify_spy

  local original_require

  local modules_to_clear_from_cache = {
    'tungsten.core.registry',
    'lpeg',
    'tungsten.core.tokenizer',
    'tungsten.util.logger',
    'tungsten.config',
  }

  local function clear_modules_from_cache()
    for _, name in ipairs(modules_to_clear_from_cache) do
      package.loaded[name] = nil
    end
  end

  local function reset_registry_state_in_module()
    if registry_module then
      registry_module.domains_metadata = {}
      registry_module.grammar_contributions = {}
      registry_module.commands = {}
    end
  end

  before_each(function()
    mock_lpeg_module = {}
    mock_tokenizer_module = {}
    mock_logger_module = {}
    mock_config_module = { debug = false }

    original_require = _G.require
    _G.require = function(module_path)
      if module_path == 'lpeg' then return mock_lpeg_module end
      if module_path == 'tungsten.core.tokenizer' then return mock_tokenizer_module end
      if module_path == 'tungsten.util.logger' then return mock_logger_module end
      if module_path == 'tungsten.config' then return mock_config_module end

      if package.loaded[module_path] then return package.loaded[module_path] end
      return original_require(module_path)
    end

    clear_modules_from_cache()

    mock_lpeg_P_spy = spy.new(function(arg)
      if type(arg) == "table" and arg[1] == "Expression" then
        return "mock_compiled_grammar_table"
      elseif type(arg) == "boolean" and not arg then
        return create_mock_pattern("P(false)")
      else
        local arg_str = (type(arg) == "table" and arg._name) or tostring(arg)
        return create_mock_pattern("P(" .. arg_str .. ")")
      end
    end)
    mock_lpeg_module.P = mock_lpeg_P_spy

    mock_lpeg_V_spy = spy.new(function(name)
      return create_mock_pattern("V(" .. name .. ")")
    end)
    mock_lpeg_module.V = mock_lpeg_V_spy

    local tokenizer_keys = {"space", "lbrace", "rbrace", "lparen", "rparen", "lbrack", "rbrack", "number", "variable", "Greek"}
    for _, key in ipairs(tokenizer_keys) do
        mock_tokenizer_module[key] = create_mock_pattern("token." .. key)
    end

    mock_logger_notify_spy = spy.new(function() end)
    mock_logger_module.notify = mock_logger_notify_spy
    mock_logger_module.levels = { ERROR = 1, WARN = 2, INFO = 3, DEBUG = 4 }

    registry_module = require("tungsten.core.registry")
    reset_registry_state_in_module()
  end)

  after_each(function()
    _G.require = original_require

    if mock_lpeg_P_spy and mock_lpeg_P_spy.clear then mock_lpeg_P_spy:clear() end
    if mock_lpeg_V_spy and mock_lpeg_V_spy.clear then mock_lpeg_V_spy:clear() end
    if mock_logger_notify_spy and mock_logger_notify_spy.clear then mock_logger_notify_spy:clear() end

    clear_modules_from_cache()
  end)

  describe("M.register_domain_metadata(name, metadata)", function()
    it("should successfully register new domain metadata", function()
      local domain_name = "test_domain"
      local metadata = { priority = 100, description = "A test domain" }
      registry_module.register_domain_metadata(domain_name, metadata)
      assert.are.same(metadata, registry_module.domains_metadata[domain_name])
    end)

    it("should store priority correctly from metadata", function()
      local domain_name = "priority_domain"
      local metadata = { priority = 150 }
      registry_module.register_domain_metadata(domain_name, metadata)
      assert.are.equal(150, registry_module.domains_metadata[domain_name].priority)
    end)

    it("should warn if re-registering metadata for an existing domain", function()
      local domain_name = "duplicate_domain"
      local metadata1 = { priority = 10 }
      local metadata2 = { priority = 20 }
      registry_module.register_domain_metadata(domain_name, metadata1)
      registry_module.register_domain_metadata(domain_name, metadata2)
      assert.spy(mock_logger_notify_spy).was.called()
      assert.spy(mock_logger_notify_spy).was.called_with(
        ("Registry: Domain metadata for '%s' is being re-registered."):format(domain_name),
        mock_logger_module.levels.WARN,
        { title = "Tungsten Registry" }
      )
      assert.are.same(metadata2, registry_module.domains_metadata[domain_name])
    end)

    it("should log registration in debug mode", function()
        mock_config_module.debug = true
        local domain_name = "debug_domain"
        local metadata = { priority = 77 }
        registry_module.register_domain_metadata(domain_name, metadata)
        assert.spy(mock_logger_notify_spy).was.called_with(
            ("Registry: Registered metadata for domain '%s' with priority %s."):format(domain_name, tostring(metadata.priority)),
            mock_logger_module.levels.DEBUG,
            { title = "Tungsten Debug" }
        )
        mock_config_module.debug = false
    end)
  end)

  describe("M.get_domain_priority(domain_name)", function()
    it("should return correct priority for a registered domain", function()
      local domain_name = "domain_with_priority"
      local metadata = { priority = 120 }
      registry_module.register_domain_metadata(domain_name, metadata)
      assert.are.equal(120, registry_module.get_domain_priority(domain_name))
    end)

    it("should return default priority (0) and log a warning if domain is not found", function()
      local domain_name = "non_existent_domain"
      local priority = registry_module.get_domain_priority(domain_name)
      assert.are.equal(0, priority)
      assert.spy(mock_logger_notify_spy).was.called_with(
        ("Registry: Priority not found for domain '%s', defaulting to 0."):format(domain_name),
        mock_logger_module.levels.WARN,
        { title = "Tungsten Registry" }
      )
    end)

    it("should return default priority (0) and log a warning if domain has no priority field in metadata", function()
      local domain_name = "domain_no_priority_field"
      local metadata = { description = "Missing priority" }
      registry_module.register_domain_metadata(domain_name, metadata)
      local priority = registry_module.get_domain_priority(domain_name)
      assert.are.equal(0, priority)
      assert.spy(mock_logger_notify_spy).was.called_with(
        ("Registry: Priority not found for domain '%s', defaulting to 0."):format(domain_name),
        mock_logger_module.levels.WARN,
        { title = "Tungsten Registry" }
      )
    end)

      it("should return default priority (0) and log a warning if domain metadata priority is nil", function()
      local domain_name = "domain_nil_priority"
      local metadata = { priority = nil }
      registry_module.register_domain_metadata(domain_name, metadata)
      local priority = registry_module.get_domain_priority(domain_name)
      assert.are.equal(0, priority)
      assert.spy(mock_logger_notify_spy).was.called_with(
        ("Registry: Priority not found for domain '%s', defaulting to 0."):format(domain_name),
        mock_logger_module.levels.WARN,
        { title = "Tungsten Registry" }
      )
    end)
  end)

  describe("M.register_grammar_contribution(domain_name, domain_priority, rule_name, pattern, category)", function()
    it("should successfully add a grammar contribution to the internal list", function()
      assert.are.equal(0, #registry_module.grammar_contributions)
      registry_module.register_grammar_contribution("domainA", 100, "Rule1", create_mock_pattern("pattern1"), "CategoryA")
      assert.are.equal(1, #registry_module.grammar_contributions)
    end)

    it("should store all parameters correctly in the contribution", function()
      local domain_name = "domainB"
      local domain_priority = 50
      local rule_name = "Rule2"
      local pattern = create_mock_pattern("pattern2_obj")
      local category = "CategoryB"
      registry_module.register_grammar_contribution(domain_name, domain_priority, rule_name, pattern, category)
      local contrib = registry_module.grammar_contributions[1]
      assert.are.equal(domain_name, contrib.domain_name)
      assert.are.equal(domain_priority, contrib.domain_priority)
      assert.are.equal(rule_name, contrib.name)
      assert.are.same(pattern, contrib.pattern)
      assert.are.equal(category, contrib.category)
    end)

    it("should default category to rule_name if category is nil", function()
      local rule_name = "Rule3"
      registry_module.register_grammar_contribution("domainC", 75, rule_name, create_mock_pattern("pattern3"), nil)
      local contrib = registry_module.grammar_contributions[1]
      assert.are.equal(rule_name, contrib.category)
    end)

    it("should log registration in debug mode", function()
        mock_config_module.debug = true
        registry_module.register_grammar_contribution("domainD", 120, "DebugRule", create_mock_pattern("dbg_pattern"), "DebugCat")
        assert.spy(mock_logger_notify_spy).was.called_with(
            ("Registry: Grammar contribution '%s' (%s) from domain '%s' (priority %d)"):format("DebugRule", "DebugCat", "domainD", 120),
            mock_logger_module.levels.DEBUG,
            { title = "Tungsten Debug" }
        )
        mock_config_module.debug = false
    end)
  end)

  describe("M.get_combined_grammar()", function()
    before_each(function()
      reset_registry_state_in_module()
      if mock_lpeg_P_spy and mock_lpeg_P_spy.clear then mock_lpeg_P_spy:clear() end
      if mock_lpeg_V_spy and mock_lpeg_V_spy.clear then mock_lpeg_V_spy:clear() end
      if mock_logger_notify_spy and mock_logger_notify_spy.clear then mock_logger_notify_spy:clear() end
    end)

    it("should handle no grammar contributions (logs error, returns P(false) for AtomBase and Expression)", function()
      local grammar = registry_module.get_combined_grammar()
      assert.spy(mock_logger_notify_spy).was.called_with(
        "Registry: No 'AtomBaseItem' contributions. AtomBase will be empty.",
        mock_logger_module.levels.WARN, { title = "Tungsten Registry" }
      )
      assert.spy(mock_logger_notify_spy).was.called_with(
        "Registry: No grammar contributions at all. 'Expression' will default to AtomBase.",
        mock_logger_module.levels.ERROR, { title = "Tungsten Registry Error" }
      )
      assert.spy(mock_lpeg_P_spy).was.called_with(false)
      assert.spy(mock_lpeg_V_spy).was.called_with("AtomBase")

      local p_calls = mock_lpeg_P_spy.calls
      local final_grammar_def_arg
      for i = #p_calls, 1, -1 do
          if type(p_calls[i].vals[1]) == "table" and p_calls[i].vals[1][1] == "Expression" then
              final_grammar_def_arg = p_calls[i].vals[1]
              break
          end
      end
      assert.is_not_nil(final_grammar_def_arg, "Final lpeg.P(grammar_table) call not found")
      assert.are.same(create_mock_pattern("P(false)"), final_grammar_def_arg.AtomBase)
      assert.are.same(create_mock_pattern("V(AtomBase)"), final_grammar_def_arg.Expression)
      assert.are.same("mock_compiled_grammar_table", grammar)
    end)

    it("should compile with AtomBaseItem contributions and default parenthesized/braced/bracketed Expression V-references", function()
      registry_module.register_grammar_contribution("core", 0, "Number", create_mock_pattern("num_pattern"), "AtomBaseItem")
      registry_module.register_grammar_contribution("core", 0, "Variable", create_mock_pattern("var_pattern"), "AtomBaseItem")
      local grammar = registry_module.get_combined_grammar()
      assert.are.same("mock_compiled_grammar_table", grammar)

      local final_call_arg = mock_lpeg_P_spy.calls[#mock_lpeg_P_spy.calls].vals[1]
      assert.is_table(final_call_arg.AtomBase)
      assert.is_true(final_call_arg.AtomBase.is_mock_pattern)

      local atom_base_str = final_call_arg.AtomBase._name
      assert.truthy(string.find(atom_base_str, "num_pattern"), "AtomBase string missing num_pattern. Got: " .. atom_base_str)
      assert.truthy(string.find(atom_base_str, "var_pattern"), "AtomBase string missing var_pattern. Got: " .. atom_base_str)
      assert.truthy(string.find(atom_base_str, "token.lbrace"), "AtomBase string missing token.lbrace for {Expr}. Got: " .. atom_base_str)
      assert.truthy(string.find(atom_base_str, "V(Expression)", 1, true), "AtomBase string missing V(Expression). Got: " .. atom_base_str)
      assert.truthy(string.find(atom_base_str, "token.rbrace"), "AtomBase string missing token.rbrace for {Expr}. Got: " .. atom_base_str)
      assert.truthy(string.find(atom_base_str, "*"), "AtomBase string missing '*' for concatenation. Got: " .. atom_base_str)
      assert.truthy(string.find(atom_base_str, "+"), "AtomBase string missing '+' for choice. Got: " .. atom_base_str)

      assert.spy(mock_logger_notify_spy).was_not.called_with(
          "Registry: No 'AtomBaseItem' contributions. AtomBase will be empty.",
          mock_logger_module.levels.WARN, { title = "Tungsten Registry" }
      )
      assert.are.same(create_mock_pattern("V(AtomBase)"), final_call_arg.Expression)
    end)

    it("Expression rule should default to V('AddSub') if AddSub is defined", function()
      registry_module.register_grammar_contribution("arithmetic", 100, "AddSub", create_mock_pattern("add_sub_pattern"), "AddSub")
      registry_module.register_grammar_contribution("core", 0, "Number", create_mock_pattern("num_pattern"), "AtomBaseItem")
      local grammar = registry_module.get_combined_grammar()
      assert.are.same("mock_compiled_grammar_table", grammar)
      local final_call_arg = mock_lpeg_P_spy.calls[#mock_lpeg_P_spy.calls].vals[1]
      assert.are.same(create_mock_pattern("V(AddSub)"), final_call_arg.Expression)
      assert.are.same(create_mock_pattern("add_sub_pattern"), final_call_arg.AddSub)
    end)

    it("Expression rule should fall back to another rule if AddSub not defined, and log warning", function()
      registry_module.register_grammar_contribution("arithmetic", 100, "MulDiv", create_mock_pattern("mul_div_pattern"), "MulDiv")
      registry_module.register_grammar_contribution("core", 0, "Number", create_mock_pattern("num_pattern"), "AtomBaseItem")
      local grammar = registry_module.get_combined_grammar()
      assert.are.same("mock_compiled_grammar_table", grammar)
      local final_call_arg = mock_lpeg_P_spy.calls[#mock_lpeg_P_spy.calls].vals[1]
      assert.are.same(create_mock_pattern("V(MulDiv)"), final_call_arg.Expression)
      assert.spy(mock_logger_notify_spy).was.called_with(
        "Registry: Main expression rule 'AddSub' not found. Attempting to find a fallback. This may lead to parsing issues.",
        mock_logger_module.levels.WARN, { title = "Tungsten Registry" }
      )
      assert.spy(mock_logger_notify_spy).was.called_with(
        "Registry: Using 'MulDiv' as a fallback for 'Expression'.",
        mock_logger_module.levels.WARN, { title = "Tungsten Registry" }
      )
    end)

    it("Expression rule defaults to V('AtomBase') if no other suitable top-level rule and logs error (AtomBase exists)", function()
        registry_module.register_grammar_contribution("core", 0, "NumberOnly", create_mock_pattern("num_pattern_item"), "AtomBaseItem")
        local grammar = registry_module.get_combined_grammar()
        assert.are.same("mock_compiled_grammar_table", grammar)
        local final_call_arg = mock_lpeg_P_spy.calls[#mock_lpeg_P_spy.calls].vals[1]
        assert.are.same(create_mock_pattern("V(AtomBase)"), final_call_arg.Expression)
        assert.spy(mock_logger_notify_spy).was.called_with(
            "Registry: Main expression rule 'AddSub' not found. Attempting to find a fallback. This may lead to parsing issues.",
            mock_logger_module.levels.WARN, { title = "Tungsten Registry" }
        )
          assert.spy(mock_logger_notify_spy).was.called_with(
            "Registry: No suitable rule found for 'Expression'. Parser will likely fail.",
            mock_logger_module.levels.ERROR, { title = "Tungsten Registry Error" }
        )
    end)

    it("should correctly sort contributions: by category, then domain_priority (desc), then name (asc)", function()
      mock_config_module.debug = true
      registry_module.register_grammar_contribution("domainA", 100, "ZZZ_Rule", create_mock_pattern("p_a_zzz"), "Op")
      registry_module.register_grammar_contribution("domainB", 200, "AAA_Rule", create_mock_pattern("p_b_aaa"), "Op")
      registry_module.register_grammar_contribution("domainC", 100, "MMM_Rule", create_mock_pattern("p_c_mmm"), "AtomBaseItem")
      registry_module.register_grammar_contribution("domainD", 150, "BBB_Rule", create_mock_pattern("p_d_bbb"), "AtomBaseItem")
      registry_module.get_combined_grammar()
      local expected_options = {title = "Tungsten Debug"}
      assert.spy(mock_logger_notify_spy).was.called_with(match.is_string(function(actual) return string.find(actual, "Sorted Grammar Contributions:", 1, true) ~= nil end), mock_logger_module.levels.DEBUG, expected_options)
      assert.spy(mock_logger_notify_spy).was.called_with(match.is_string(function(actual) return string.find(actual, "1. BBB_Rule (AtomBaseItem) from domainD (Prio: 150)", 1, true) ~= nil end), mock_logger_module.levels.DEBUG, expected_options)
      assert.spy(mock_logger_notify_spy).was.called_with(match.is_string(function(actual) return string.find(actual, "2. MMM_Rule (AtomBaseItem) from domainC (Prio: 100)", 1, true) ~= nil end), mock_logger_module.levels.DEBUG, expected_options)
      assert.spy(mock_logger_notify_spy).was.called_with(match.is_string(function(actual) return string.find(actual, "3. AAA_Rule (Op) from domainB (Prio: 200)", 1, true) ~= nil end), mock_logger_module.levels.DEBUG, expected_options)
      assert.spy(mock_logger_notify_spy).was.called_with(match.is_string(function(actual) return string.find(actual, "4. ZZZ_Rule (Op) from domainA (Prio: 100)", 1, true) ~= nil end), mock_logger_module.levels.DEBUG, expected_options)
      mock_config_module.debug = false
    end)

    it("Rule Overriding: Higher priority domain's rule overrides lower priority for same name, logs debug", function()
      mock_config_module.debug = true
      registry_module.register_domain_metadata("LowPrioDomain", { priority = 50 })
      registry_module.register_domain_metadata("HighPrioDomain", { priority = 100 })
      registry_module.register_grammar_contribution("LowPrioDomain", 50, "MyRule", create_mock_pattern("low_pattern"), "MyCategory")
      registry_module.register_grammar_contribution("HighPrioDomain", 100, "MyRule", create_mock_pattern("high_pattern"), "MyCategory")
      registry_module.get_combined_grammar()
      local final_call_arg = mock_lpeg_P_spy.calls[#mock_lpeg_P_spy.calls].vals[1]
      assert.are.same(create_mock_pattern("high_pattern"), final_call_arg.MyRule)
      assert.spy(mock_logger_notify_spy).was.called_with(
        ("Registry: Rule '%s': %s (Prio %d) NOT overriding %s (Prio %d)."):format(
          "MyRule", "LowPrioDomain", 50, "HighPrioDomain", 100
        ),
        mock_logger_module.levels.DEBUG, { title = "Tungsten Registry" }
      )
      mock_config_module.debug = false
    end)

    it("Rule Non-Overriding: Lower priority does not override higher, logs debug", function()
      mock_config_module.debug = true
      registry_module.register_domain_metadata("HighPrioDomain", { priority = 100 })
      registry_module.register_domain_metadata("LowPrioDomain", { priority = 50 })
      registry_module.register_grammar_contribution("HighPrioDomain", 100, "MyRule", create_mock_pattern("high_pattern"), "MyCategory")
      registry_module.register_grammar_contribution("LowPrioDomain", 50, "MyRule", create_mock_pattern("low_pattern"), "MyCategory")
      registry_module.get_combined_grammar()
      local final_call_arg = mock_lpeg_P_spy.calls[#mock_lpeg_P_spy.calls].vals[1]
      assert.are.same(create_mock_pattern("high_pattern"), final_call_arg.MyRule)
      assert.spy(mock_logger_notify_spy).was.called_with(
        ("Registry: Rule '%s': %s (Prio %d) NOT overriding %s (Prio %d)."):format(
          "MyRule", "LowPrioDomain", 50, "HighPrioDomain", 100
        ),
        mock_logger_module.levels.DEBUG, { title = "Tungsten Registry" }
      )
      mock_config_module.debug = false
    end)

    it("Conflict Handling (Same Priority): One takes precedence due to sort order, logs warning", function()
      registry_module.register_domain_metadata("DomainA", { priority = 100 })
      registry_module.register_domain_metadata("DomainB", { priority = 100 })
      registry_module.register_grammar_contribution("DomainA", 100, "MyRule", create_mock_pattern("pattern_A"), "MyCategory")
      registry_module.register_grammar_contribution("DomainB", 100, "MyRule", create_mock_pattern("pattern_B"), "MyCategory")
      registry_module.get_combined_grammar()
      local final_call_arg = mock_lpeg_P_spy.calls[#mock_lpeg_P_spy.calls].vals[1]

      assert.are.same(create_mock_pattern("pattern_B"), final_call_arg.MyRule)
      assert.spy(mock_logger_notify_spy).was.called_with(
        ("Registry: Rule '%s': CONFLICT/AMBIGUITY - %s (Prio %d) and %s (Prio %d) have same priority. '%s' takes precedence due to sort order."):format(
          "MyRule", "DomainB", 100, "DomainA", 100, "DomainB"
        ),
        mock_logger_module.levels.WARN, { title = "Tungsten Registry Conflict" }
      )
    end)

    it("should return nil and log error if lpeg.P fails on final grammar definition", function()
      registry_module.register_grammar_contribution("core", 0, "Number", create_mock_pattern("num_pattern"), "AtomBaseItem")

      local original_P_func = mock_lpeg_module.P
      mock_lpeg_module.P = spy.new(function(gdef)
        if type(gdef) == "table" and gdef[1] == "Expression" then
          error("mock LPeg compilation error")
            return create_mock_pattern("P_other_call_in_fail_test(" .. tostring(gdef) .. ")")
        end
      end)

      local grammar = registry_module.get_combined_grammar()
      assert.is_nil(grammar)
      assert.spy(mock_logger_notify_spy).was.called_with(
        match.is_string(function(str) return string.find(str, "Registry: Error compiling final grammar table:", 1, true) and string.find(str, "mock LPeg compilation error", 1, true) end),
        mock_logger_module.levels.ERROR,
        { title = "Tungsten Registry Error" }
      )
      mock_lpeg_module.P = original_P_func
    end)

    it("State Management: ensure get_combined_grammar is relatively stateless for multiple calls", function()
      registry_module.register_grammar_contribution("domain1", 10, "RuleX", create_mock_pattern("patX1"), "CatX")
      local grammar1 = registry_module.get_combined_grammar()
      assert.are.same("mock_compiled_grammar_table", grammar1)
      local final_call_arg1 = mock_lpeg_P_spy.calls[#mock_lpeg_P_spy.calls].vals[1]
      assert.are.same(create_mock_pattern("patX1"), final_call_arg1.RuleX)

      reset_registry_state_in_module()
      mock_lpeg_P_spy:clear()
      mock_lpeg_V_spy:clear()
      mock_logger_notify_spy:clear()

      registry_module.register_grammar_contribution("domain2", 20, "RuleX", create_mock_pattern("patX2_new"), "CatX")
      registry_module.register_grammar_contribution("domain2", 20, "RuleY", create_mock_pattern("patY2"), "CatY")
      local grammar2 = registry_module.get_combined_grammar()
      assert.are.same("mock_compiled_grammar_table", grammar2)
      local final_call_arg2 = mock_lpeg_P_spy.calls[#mock_lpeg_P_spy.calls].vals[1]
      assert.are.same(create_mock_pattern("patX2_new"), final_call_arg2.RuleX)
      assert.are.same(create_mock_pattern("patY2"), final_call_arg2.RuleY)
      assert.is_nil(final_call_arg2.RuleZ)
    end)

    it("should log final grammar definition keys in debug mode", function()
        mock_config_module.debug = true
        registry_module.register_grammar_contribution("arithmetic", 100, "AddSub", create_mock_pattern("add_sub_pattern"), "AddSub")
        registry_module.register_grammar_contribution("core", 0, "Number", create_mock_pattern("num_pattern"), "AtomBaseItem")
        registry_module.get_combined_grammar()
        assert.spy(mock_logger_notify_spy).was.called_with(
            match.is_string(function(actual)
                return string.find(actual, "Registry: Final grammar definition keys:") and
                       string.find(actual, "AddSub") and
                       string.find(actual, "AtomBase") and
                       string.find(actual, "Expression")
            end),
            mock_logger_module.levels.DEBUG, { title = "Tungsten Debug" }
        )
        mock_config_module.debug = false
    end)

    it("should log AtomBaseItem additions in debug mode", function()
        mock_config_module.debug = true
        registry_module.register_grammar_contribution("core", 0, "MyNum", create_mock_pattern("num_pat"), "AtomBaseItem")
        registry_module.get_combined_grammar()
        assert.spy(mock_logger_notify_spy).was.called_with(
            "Registry: Adding AtomBaseItem pattern for 'MyNum' from core.",
            mock_logger_module.levels.DEBUG, {title="Tungsten Debug"}
        )
        mock_config_module.debug = false
    end)
  end)
end)
