-- tests/unit/domains/differential_equations/wolfram_handlers_spec.lua
-- Busted tests for the differential equations Wolfram handlers.

describe("Differential Equations Wolfram Handlers", function()
  local handlers
  local mock_render

  before_each(function()
    handlers = require "tungsten.domains.differential_equations.wolfram_handlers".handlers

    mock_render = function(node)
      if not node or not node.type then return "" end

      if node.type == "variable" then
        return node.name
      elseif node.type == "function_call" then
        local arg_str = ""
        if node.args and #node.args > 0 then
          local rendered_args = {}
          for _, arg in ipairs(node.args) do
            table.insert(rendered_args, mock_render(arg))
          end
          arg_str = table.concat(rendered_args, ", ")
        end
        return mock_render(node.name_node) .. "[" .. arg_str .. "]"
      elseif node.type == "derivative" then
        local var_name = node.variable.name or "y"
        local order = node.order or 1
        local order_str = string.rep("'", order)
        local indep_var = (node.independent_variable and node.independent_variable.name) or "x"
        return var_name .. order_str .. "[" .. indep_var .. "]"
      end
      return ""
    end
  end)

  describe("ode handler", function()
    it("should generate a full DSolve command for a single ODE", function()
      local ast = {
        type = "ode",
        lhs = { type = "derivative", order = 1, variable = { type = "variable", name = "y" } },
        rhs = { type = "variable", name = "y" },
      }
      local result = handlers.ode(ast, mock_render)
      assert.are.same("DSolve[y'[x] == y, y[x], x]", result)
    end)
  end)

  describe("ode_system handler", function()
    it("should generate a full DSolve command for a system of ODEs", function()
      local ast = {
        type = "ode_system",
        equations = {
          {
            type = "ode",
            lhs = { type = "derivative", order = 1, variable = { type = "variable", name = "y" } },
            rhs = { type = "variable", name = "z" },
          },
          {
            type = "ode",
            lhs = { type = "derivative", order = 1, variable = { type = "variable", name = "z" } },
            rhs = { type = "variable", name = "y" },
          },
        },
      }
      local result = handlers.ode_system(ast, mock_render)
      assert.is_true(
        result == "DSolve[{y'[x] == z, z'[x] == y}, {y[x], z[x]}, x]"
        or result == "DSolve[{y'[x] == z, z'[x] == y}, {z[x], y[x]}, x]"
      )
    end)
  end)

  describe("wronskian handler", function()
    it("should correctly format the Wronskian function", function()
      local ast = {
        type = "wronskian",
        functions = {
          { type = "variable", name = "f" },
          { type = "variable", name = "g" },
        },
      }
      local result = handlers.wronskian(ast, mock_render)
      assert.are.same("Wronskian[{f, g}, x]", result)
    end)
  end)

  describe("laplace_transform handler", function()
    it("should correctly format the LaplaceTransform function", function()
      local ast = {
        type = "laplace_transform",
        expression = {
          type = "function_call",
          name_node = { type = "variable", name = "f" },
          args = { { type = "variable", name = "t" } },
        },
      }
      local result = handlers.laplace_transform(ast, mock_render)
      assert.are.same("LaplaceTransform[f[t], t, s]", result)
    end)
  end)

  describe("inverse_laplace_transform handler", function()
    it("should correctly format the InverseLaplaceTransform function", function()
      local ast = {
        type = "inverse_laplace_transform",
        expression = {
          type = "function_call",
          name_node = { type = "variable", name = "F" },
          args = { { type = "variable", name = "s" } },
        },
      }
      local result = handlers.inverse_laplace_transform(ast, mock_render)
      assert.are.same("InverseLaplaceTransform[F[s], s, t]", result)
    end)
  end)

  describe("convolution handler", function()
    it("should correctly format the Convolve function", function()
      local ast = {
        type = "convolution",
        left = { type = "variable", name = "f" },
        right = { type = "variable", name = "g" },
      }
      local result = handlers.convolution(ast, mock_render)
      assert.are.same("Convolve[f, g, t, y]", result)
    end)
  end)
end)
