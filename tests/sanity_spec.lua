-- tests/sanity_spec.lua

-- This is a basic Busted test suite.
-- We'll define a 'describe' block to group related tests.
describe('Busted Sanity Check', function()
  -- Inside the 'describe' block, we define individual test cases
  -- using 'it' blocks.

  -- This test checks if Busted is working by asserting a simple truth.
  it('should confirm that true is true', function()
    -- 'assert.is_true' is a Busted assertion.
    -- It checks if the provided value is true.
    assert.is_true(true)
  end)

  -- You can add more 'it' blocks for other basic checks.
  it('should confirm that nil is nil', function()
    assert.is_nil(nil)
  end)

  it('should confirm that a string is a string', function()
    assert.is_string("hello busted")
  end)
end)

