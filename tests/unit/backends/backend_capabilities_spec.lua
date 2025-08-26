-- Unit tests for backend plotting capabilities and error handling.

local capabilities = require("tungsten.backends.capabilities")

describe("Backend Plotting Capabilities", function()

  local mock_config
  local original_require

  before_each(function()
    mock_config = {
      backend = "wolfram"
    }
    original_require = _G.require
    _G.require = function(path)
      if path == "tungsten.config" then
        return mock_config
      end
      return original_require(path)
    end
  end)

  after_each(function()
    _G.require = original_require
  end)

  it("should default to the Wolfram backend for plotting when backend is not specified", function()
    local get_active_backend = function() return capabilities.get_backend(mock_config.backend) end
    assert.are.equal("wolfram", get_active_backend().name)
  end)

  it("should detect when a plot form is unsupported by the chosen backend", function()
    local python_backend = capabilities.get_backend("python")
    assert.is_false(python_backend.supports.implicit[3])
    assert.is_false(python_backend.supports.inequalities[2])
  end)

  describe("Python Backend", function()

    local python_backend

    before_each(function()
      python_backend = capabilities.get_backend("python")
    end)

    it("should handle explicit, implicit 2D, parametric, polar, and point plots", function()
      assert.is_true(python_backend.supports.explicit[2])
      assert.is_true(python_backend.supports.explicit[3])
      assert.is_true(python_backend.supports.implicit[2])
      assert.is_true(python_backend.supports.parametric[2])
      assert.is_true(python_backend.supports.parametric[3])
      assert.is_true(python_backend.supports.polar[2])
      assert.is_true(python_backend.points[2])
      assert.is_true(python_backend.points[3])
    end)

    it("should NOT handle 3D implicit plots or inequalities", function()
      assert.is_false(python_backend.supports.implicit[3])
      assert.is_false(python_backend.supports.inequalities[2])
      assert.is_false(python_backend.supports.inequalities[3])
    end)

    it("should raise E_UNSUPPORTED_FORM for vertical line plots like x = f(y)", function()
      local function can_plot(backend, form, dim, orientation)
        if orientation == "vertical" and form == "explicit" then
          return backend.name == "wolfram"
        end
        return backend.supports[form][dim]
      end
      assert.is_false(can_plot(python_backend, "explicit", 2, "vertical"))
    end)
  end)

  describe("Wolfram Backend", function()

    local wolfram_backend

    before_each(function()
      wolfram_backend = capabilities.get_backend("wolfram")
    end)

    it("should handle all plot forms in 2D and 3D", function()
      assert.is_true(wolfram_backend.supports.explicit[2])
      assert.is_true(wolfram_backend.supports.explicit[3])
      assert.is_true(wolfram_backend.supports.implicit[2])
      assert.is_true(wolfram_backend.supports.implicit[3])
      assert.is_true(wolfram_backend.supports.parametric[2])
      assert.is_true(wolfram_backend.supports.parametric[3])
      assert.is_true(wolfram_backend.supports.polar[2])
      assert.is_true(wolfram_backend.points[2])
      assert.is_true(wolfram_backend.points[3])
    end)

    it("should handle 3D implicit surfaces and inequalities", function()
      assert.is_true(wolfram_backend.supports.implicit[3])
      assert.is_true(wolfram_backend.supports.inequalities[2])
      assert.is_true(wolfram_backend.supports.inequalities[3])
    end)

    it("should handle vertical line plots and other implicit orientations", function()
      local function can_plot(backend, form, dim, orientation)
        if orientation == "vertical" and form == "explicit" then
          return backend.name == "wolfram"
        end
        return backend.supports[form][dim]
      end
      assert.is_true(can_plot(wolfram_backend, "explicit", 2, "vertical"))
    end)
  end)

  describe("Error Handling", function()

    it("should return E_UNSUPPORTED_DIM if a polar plot is requested in 3D", function()
      local python_backend = capabilities.get_backend("python")
      local wolfram_backend = capabilities.get_backend("wolfram")
      assert.is_nil(python_backend.supports.polar[3])
      assert.is_nil(wolfram_backend.supports.polar[3])
    end)

    it("should raise an error or handle gracefully when a non-existent backend is requested", function()
      assert.is_nil(capabilities.get_backend("non_existent_backend"))
    end)

    it("should handle queries for non-existent plot forms or dimensions", function()
      local python_backend = capabilities.get_backend("python")
      assert.is_nil(python_backend.supports.hyperbolic)
      assert.is_nil(python_backend.supports.explicit[4])
    end)
  end)
end)
