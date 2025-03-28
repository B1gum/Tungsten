-- parser/AST.lua
-- AST-module
---------------------------------------

local AST = {}

function AST.Number(value)                      -- AST construct for normal numbers
  return {
    tag = "Number",
    value = value
  }
end

function AST.Constant(value)                    -- AST construct for mathematical constants
  return {
    tag = "Constant",
    name = value
  }
end

function AST.Variable(value)                    -- AST construct for variables
  return {
    tag = "Variable",
    name = value
  }
end

function AST.Add(left,  right)                  -- AST construct for addition operation
  return {
    tag = "Add",
    left = left,
    right = right
  }
end

function AST.Sub(left, right)                   -- AST construct for subtraction operation
  return {
    tag = "Sub",
    left = left,
    right = right }
end

function AST.Mul(left, right)                   -- AST construct for multiplication operation
  return {
    tag = "Mul",
    left = left,
    right = right
  }
end

function AST.Div(num, den)                      -- AST construct for division operation
  return {
    tag = "Div",
    num = num,
    den = den
  }
end

function AST.Pow(base, exp)                     -- AST construct for exponentiartion operation
  return {
    tag = "Pow",
    base = base,
    exp = exp
  }
end

function AST.FunctionCall(fname, arg)           -- AST construct for function calls like \cos ans \sin
  return {
    tag = "FunctionCall",
    name = fname,
    arg = arg
  }
end

function AST.Int(integrand, var, lower, upper)  -- AST construct for integrals
  return {
    tag = "Integral",
    integrand = integrand,
    var = var,
    lower = lower,  -- optional; nil for indefinite integrals
    upper = upper   -- optional; nil for indefinite integrals
  }
end

function AST.Derivative(expr, var, order)
  return {
    tag = "Derivative",
    expr = expr,
    var = var,
    order = order or 1
  }
end

function AST.PartialDerivative(expr, var, order)
  return {
    tag = "PartialDerivative",
    expr = expr,
    var = var,
    order = order or 1
  }
end

function AST.Limit(expr, var, point, direction)
  return {
    tag = "Limit",
    expr = expr,            -- the expression to take the limit of
    var = var,              -- the variable that approaches the limit
    point = point,          -- the value the variable is approaching
    direction = direction  -- optional (e.g. "FromAbove" or "FromBelow")
  }
end

function AST.toWolfram(node)  -- Function to recursively turn AST into WolframScript
  if node.tag == "Number" then
    return tostring(node.value)       -- Pass literal value of numbers
  elseif node.tag == "Variable" then
    if node.name == nil then
      error("Variable node is missing a name field: " .. require("vim.inspect")(node))
    end
    return tostring(node.name)        -- Pass literal name of variables
  elseif node.tag == "Constant" then
    if node.name == "\\pi" then
      return "Pi"                     -- Pass Pi for \pi
    elseif node.name == "e" then
      return "E"                      -- Turn e into E
    elseif node.name == "\\infty" then
      return "Infinity"               -- Turn \infty to Infinity
    else
      return tostring(node.name)
    end
  elseif node.tag == "Add" then
    return "(" .. AST.toWolfram(node.left) .. " + " .. AST.toWolfram(node.right) .. ")"   -- Addition as +-operator
  elseif node.tag == "Sub" then
    return "(" .. AST.toWolfram(node.left) .. " - " .. AST.toWolfram(node.right) .. ")"   -- Subtraction as '-'-operator
  elseif node.tag == "Mul" then
    return "(" .. AST.toWolfram(node.left) .. " * " .. AST.toWolfram(node.right) .. ")"   -- Multiplication as *-operator
  elseif node.tag == "Div" then
    return "(" .. AST.toWolfram(node.num) .. " / " .. AST.toWolfram(node.den) .. ")"      -- Division as /-operator
  elseif node.tag == "Pow" then
    return AST.toWolfram(node.base) .. "^(" .. AST.toWolfram(node.exp) .. ")"             -- Exponentiation as ^-operator
  elseif node.tag == "FunctionCall" then
    if node.name == nil then
      error("FunctionCall node is missing a name field: " .. require("vim.inspect")(node))
    end
    return tostring(node.name) .. "[" .. AST.toWolfram(node.arg) .. "]"                   -- Function calls are handled as <function>[<arg>]
  elseif node.tag == "Integral" then
    local integrandStr = AST.toWolfram(node.integrand)
    local varStr = AST.toWolfram(node.var)
    if node.lower and node.upper then
      return string.format("Integrate[%s, {%s, %s, %s}]", integrandStr, varStr, AST.toWolfram(node.lower), AST.toWolfram(node.upper))   -- Definite integral
    else
      return string.format("Integrate[%s, %s]", integrandStr, varStr)   -- Indefinite integral
    end
  elseif node.tag == "Derivative" then
    local exprStr = AST.toWolfram(node.expr)
    local varStr  = AST.toWolfram(node.var)
    if node.order and node.order > 1 then
      return string.format("D[%s, {%s, %s}]", exprStr, varStr, tostring(node.order))
    else
      return string.format("D[%s, %s]", exprStr, varStr)
    end
  elseif node.tag == "PartialDerivative" then
    local exprStr = AST.toWolfram(node.expr)
    local varStr  = AST.toWolfram(node.var)
    if node.order and node.order > 1 then
      return string.format("D[%s, {%s, %s}]", exprStr, varStr, tostring(node.order))
    else
      return string.format("D[%s, %s]", exprStr, varStr)
    end
  elseif node.tag == "Limit" then
    local exprStr = AST.toWolfram(node.expr)
    local varStr  = AST.toWolfram(node.var)
    local pointStr = AST.toWolfram(node.point)
    if node.direction then
      local dirVal = (node.direction == "+" and "-1" or node.direction == "-" and "1" or node.direction)
      return string.format("Limit[%s, %s -> %s, Direction -> %s]", exprStr, varStr, pointStr, dirVal)
    else
      return string.format("Limit[%s, %s -> %s]", exprStr, varStr, pointStr)
    end
  else
    error("Unknown AST node type: " .. tostring(node.tag))
  end
end

return AST
