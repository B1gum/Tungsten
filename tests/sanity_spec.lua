-- tests/sanity_spec.lua

describe('Busted Sanity Check', function()
  it('should confirm that true is true', function()
    assert.is_true(true)
  end)

  it('should confirm that nil is nil', function()
    assert.is_nil(nil)
  end)

  it('should confirm that a string is a string', function()
    assert.is_string("hello busted")
  end)
end)

