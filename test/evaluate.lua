-- test/evaluate.lua
-- Test script for evaluation command
---------------------------------------------

local AST = require("tungsten.parser.AST")
local eval = require("tungsten.evaluate")
local inspect = require("vim.inspect")

-- Test 1: Evaluate a simple arithmetic expression: 2 + 2
do
  print("Test 1: Evaluating 2 + 2")
  local ast1 = AST.Add(AST.Number(2), AST.Number(2))
  local code1 = AST.toWolfram(ast1)
  print("Generated WolframScript code: " .. code1)

  local result1 = eval.evaluate(ast1, false)  -- false for symbolic evaluation
  print("Result: " .. result1)
  print("---------")
end

-- Test 2: Evaluate an exponentiation expression: 3^2
do
  print("Test 2: Evaluating 3^2")
  local ast2 = AST.Pow(AST.Number(3), AST.Number(2))
  local code2 = AST.toWolfram(ast2)
  print("Generated WolframScript code: " .. code2)

  local result2 = eval.evaluate(ast2, false)
  print("Result: " .. result2)
  print("---------")
end

-- Test 3: Evaluate a fraction: \frac{1}{2}
do
  print("Test 3: Evaluating \\frac{1}{2}")
  local ast3 = AST.Div(AST.Number(1), AST.Number(2))
  local code3 = AST.toWolfram(ast3)
  print("Generated WolframScript code: " .. code3)

  local result3 = eval.evaluate(ast3, false)
  print("Result: " .. result3)
  print("---------")
end

-- Test 4: Evaluate a combined expression: (1+2)*x
-- Note: Since 'x' is an unassigned variable, WolframScript may return the unevaluated expression.
do
  print("Test 4: Evaluating (1+2)*x")
  local ast4 = AST.Mul(
                AST.Add(AST.Number(1), AST.Number(2)),
                AST.Variable("x")
              )
  local code4 = AST.toWolfram(ast4)
  print("Generated WolframScript code: " .. code4)

  local result4 = eval.evaluate(ast4, false)
  print("Result: " .. result4)
  print("---------")
end

-- Test 5: Evaluate an expression with multiplication by a constant: 31.1232 \cdot \pi
do
  print("Test 5: Evaluating 31.1232 \\cdot \\pi")
  local ast5 = AST.Mul(
                AST.Number(31.1232),
                AST.Constant("pi")
              )
  local code5 = AST.toWolfram(ast5)
  print("Generated WolframScript code: " .. code5)

  local result5 = eval.evaluate(ast5, false)
  print("Result: " .. result5)
  print("---------")
end

print("All tests complete.")
