-- simple_check_spec.lua
describe("Busted & Luassert Env Check", function()
  it("should load Busted's core and Luassert components", function()
    local busted_core_ok, busted_core_mod = pcall(require, "busted.core")
    assert.is_true(busted_core_ok, "Failed to load busted.core: " .. tostring(busted_core_mod))

    -- Try to load luassert (which Busted depends on for asserts, spies, mocks)
    local luassert_ok, luassert_mod = pcall(require, "luassert")
    assert.is_true(luassert_ok, "Failed to load luassert: " .. tostring(luassert_mod))

    -- If luassert loads, try to access its spy and match capabilities
    if luassert_ok then
      local spy_mod_ok, spy_mod = pcall(require, "luassert.spy") -- Luassert often provides spy
      assert.is_true(spy_mod_ok, "Failed to load luassert.spy: " .. tostring(spy_mod))
      assert.is_not_nil(spy_mod.on, "spy_mod.on is nil")

      local match_mod_ok, match_mod = pcall(require, "luassert.match")
      assert.is_true(match_mod_ok, "Failed to load luassert.match: " .. tostring(match_mod))
      assert.is_not_nil(match_mod.contains, "match_mod.contains is nil")
    end
  end)
end)
