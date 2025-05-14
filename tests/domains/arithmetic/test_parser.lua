package.path = "./lua/?.lua;./lua/?/init.lua;" .. package.path

-- Ensure Tungsten core and its domains are initialized before parser is used in tests
if not _G.__TUNGSTEN_CORE_INITIALIZED_FOR_TESTS then
  print("Test Environment: Initializing Tungsten core...")
  require("tungsten.core") -- This should trigger the loading of domains
                           -- and execution of their init_grammar()
  _G.__TUNGSTEN_CORE_INITIALIZED_FOR_TESTS = true
  print("Test Environment: Tungsten core initialization complete.")
end

-- Now require the parser (or other modules you need for the test)
local core = require("tungsten.core.parser")


-- simple serializer for error‐messages
local function serialize(x)
  if type(x) ~= "table" then
    return tostring(x)
  end
  local parts = {}
  for k, v in pairs(x) do
    parts[#parts+1] = tostring(k) .. "=" .. serialize(v)
  end
  return "{" .. table.concat(parts, ", ") .. "}"
end

-- deep comparison of AST tables
local function deep_eq(a, b)
  if type(a) ~= type(b) then return false end
  if type(a) ~= "table" then
    return a == b
  end
  for k,v in pairs(a) do
    if not deep_eq(v, b[k]) then return false end
  end
  for k in pairs(b) do
    if a[k] == nil then return false end
  end
  return true
end

-- test‐cases
local tests = {
  -- 1. simple integer
  {
    input = "123",
    expected = { type="number", value=123 }
  },
  -- 2. simple superscript
  {
    input = "a^2",
    expected = {
      type="superscript",
      base     = { type="variable", name="a" },
      exponent = { type="number",   value=2 }
    }
  },
  -- 3. simple fraction
  {
    input = "\\frac{1}{x+1}",
    expected = {
      type="fraction",
      numerator   = { type="number", value=1 },
      denominator = {
        type="binary", operator="+",
        left  = { type="variable", name="x" },
        right = { type="number",   value=1 }
      }
    }
  },
  -- 4. decimal number
  {
    input = "3.14",
    expected = { type="number", value=3.14 }
  },
  -- 5. multi‐letter variable
  {
    input = "theta",
    expected = { type="variable", name="theta" }
  },
  -- 6. Greek letter
  {
    input = "\\alpha",
    expected = { type="greek", name="alpha" }
  },
  -- 7. chained subtraction/addition
  {
    input = "1-2+3",
    expected = {
      type="binary", operator="+",
      left = {
        type="binary", operator="-",
        left  = { type="number", value=1 },
        right = { type="number", value=2 }
      },
      right = { type="number", value=3 }
    }
  },
  -- 8. multiplication via \\cdot
  {
    input = "a \\cdot b",
    expected = {
      type="binary", operator="*",
      left  = { type="variable", name="a" },
      right = { type="variable", name="b" }
    }
  },
  -- 9. parentheses grouping + multiplication
  {
    input = "(a+b)\\cdot c",
    expected = {
      type="binary", operator="*",
      left = {
        type="binary", operator="+",
        left  = { type="variable", name="a" },
        right = { type="variable", name="b" }
      },
      right = { type="variable", name="c" }
    }
  },
  -- 10. square‐brackets grouping
  {
    input = "[x-y]",
    expected = {
      type="binary", operator="-",
      left  = { type="variable", name="x" },
      right = { type="variable", name="y" }
    }
  },
  -- 11. nested braces/brackets
  {
    input = "{[x]}",
    expected = { type="variable", name="x" }
  },
  -- 12. simple subscript
  {
    input = "x_i",
    expected = {
      type="subscript",
      base      = { type="variable", name="x" },
      subscript = { type="variable", name="i" }
    }
  },
  -- 13. braced superscript with expression
  {
    input = "x^{i+1}",
    expected = {
      type="superscript",
      base     = { type="variable", name="x" },
      exponent = {
        type="binary", operator="+",
        left  = { type="variable", name="i" },
        right = { type="number",   value=1 }
      }
    }
  },
  -- 14. mixed subscript then superscript
  {
    input = "x_i^2",
    expected = {
      type="superscript",
      base = {
        type="subscript",
        base      = { type="variable", name="x" },
        subscript = { type="variable", name="i" }
      },
      exponent = { type="number", value=2 }
    }
  },
  -- 15. nested fractions
  {
    input = "\\frac{\\frac{1}{2}}{3}",
    expected = {
      type="fraction",
      numerator = {
        type="fraction",
        numerator   = { type="number", value=1 },
        denominator = { type="number", value=2 }
      },
      denominator = { type="number", value=3 }
    }
  },
  -- 16. nested square‐roots
  {
    input = "\\sqrt{\\sqrt{2}}",
    expected = {
      type="sqrt",
      radicand = {
        type="sqrt",
        radicand = { type="number", value=2 }
      }
    }
  },
  -- 17. sqrt of sum of squares
  {
    input = "\\sqrt{a^2 + b^2}",
    expected = {
      type="sqrt",
      radicand = {
        type="binary", operator="+",
        left = {
          type="superscript",
          base     = { type="variable", name="a" },
          exponent = { type="number",   value=2 }
        },
        right = {
          type="superscript",
          base     = { type="variable", name="b" },
          exponent = { type="number",   value=2 }
        }
      }
    }
  },
  -- 18. complex mix: grouped sub/sup then overall superscript
  {
    input = "(x_{i+1}+y_2)^3",
    expected = {
      type="superscript",
      base = {
        type="binary", operator="+",
        left = {
          type="subscript",
          base      = { type="variable", name="x" },
          subscript = {
            type="binary", operator="+",
            left  = { type="variable", name="i" },
            right = { type="number",   value=1 }
          }
        },
        right = {
          type="subscript",
          base      = { type="variable", name="y" },
          subscript = { type="number", value=2 }
        }
      },
      exponent = { type="number", value=3 }
    }
  },
  -- 19. nested subscripts
  {
    input = "x_{i_j_k}",
    expected = {
      type="subscript",
      base = { type="variable", name="x" },
      subscript = {
        type="subscript",
        base = {
          type="subscript",
          base      = { type="variable", name="i" },
          subscript = { type="variable", name="j" }
        },
        subscript = { type="variable", name="k" }
      }
    }
  },
  -- 20. fraction + nested subscript in denominator
  {
    input = "\\frac{\\sqrt{a}}{b_{c_d}}",
    expected = {
      type="fraction",
      numerator = {
        type="sqrt",
        radicand = { type="variable", name="a" }
      },
      denominator = {
        type="subscript",
        base      = { type="variable", name="b" },
        subscript = {
          type="subscript",
          base      = { type="variable", name="c" },
          subscript = { type="variable", name="d" }
        }
      }
    }
  },
  -- 21. sqrt of a fraction containing another sqrt
  {
    input = "\\sqrt{\\frac{1}{\\sqrt{2}}}",
    expected = {
      type="sqrt",
      radicand = {
        type="fraction",
        numerator   = { type="number", value=1 },
        denominator = {
          type="sqrt",
          radicand = { type="number", value=2 }
        }
      }
    }
  },
  -- 22. chained mul/div
  {
    input = "a*b/c*d",
    expected = {
      type="binary", operator="*",
      left = {
        type="binary", operator="/",
        left = {
          type="binary", operator="*",
          left  = { type="variable", name="a" },
          right = { type="variable", name="b" }
        },
        right = { type="variable", name="c" }
      },
      right = { type="variable", name="d" }
    }
  },
  -- 23. chained superscripts
  {
    input = "a^b^c",
    expected = {
      type="superscript",
      base = {
        type="superscript",
        base     = { type="variable", name="a" },
        exponent = { type="variable", name="b" }
      },
      exponent = { type="variable", name="c" }
    }
  },
  -- 24. Greek subscript
  {
    input = "\\lambda_{n+1}",
    expected = {
      type="subscript",
      base      = { type="greek", name="lambda" },
      subscript = {
        type="binary", operator="+",
        left  = { type="variable", name="n" },
        right = { type="number",   value=1 }
      }
    }
  },
  -- 25. alphanumeric variable
  {
    input = "abc123",
    expected = { type="variable", name="abc123" }
  },
  -- 26. explicit * with parentheses
  {
    input = "5 \\cdot (x-3)",
    expected = {
      type="binary", operator="*",
      left  = { type="number",   value=5 },
      right = {
        type="binary", operator="-",
        left  = { type="variable", name="x" },
        right = { type="number",   value=3 }
      }
    }
  },
  -- 26.a implicit * with parentheses
  {
    input = "5(x-3)",
    expected = {
      type="binary", operator="*",
      left  = { type="number",   value=5 },
      right = {
        type="binary", operator="-",
        left  = { type="variable", name="x" },
        right = { type="number",   value=3 }
      }
    }
  },

  -- 27. fraction with bracket & paren in numerator/denominator
  {
    input = "\\frac{[1]}{(2)}",
    expected = {
      type="fraction",
      numerator   = { type="number", value=1 },
      denominator = { type="number", value=2 }
    }
  },
  -- 28. sup then sub
  {
    input = "x^2_3",
    expected = {
      type="subscript",
      base = {
        type="superscript",
        base     = { type="variable", name="x" },
        exponent = { type="number",   value=2 }
      },
      subscript = { type="number", value=3 }
    }
  },
  -- 29. sqrt with superscript
  {
    input = "\\sqrt{a}^3",
    expected = {
      type="superscript",
      base = {
        type="sqrt",
        radicand = { type="variable", name="a" }
      },
      exponent = { type="number", value=3 }
    }
  },
  -- 30. deeply nested fraction + sqrt on both sides
  {
    input = "\\frac{\\sqrt{\\frac{1}{2}}}{\\sqrt{\\frac{3}{4}}}",
    expected = {
      type="fraction",
      numerator = {
        type="sqrt",
        radicand = {
          type="fraction",
          numerator   = { type="number", value=1 },
          denominator = { type="number", value=2 }
        }
      },
      denominator = {
        type="sqrt",
        radicand = {
          type="fraction",
          numerator   = { type="number", value=3 },
          denominator = { type="number", value=4 }
        }
      }
    }
  },
  -- 31. unary minus
  {
    input = "-x",
    expected = {
      type     = "unary",
      operator = "-",
      value    = { type="variable", name="x" }
    }
  },
  -- 32. unary plus
  {
    input = "+y",
    expected = {
      type     = "unary",
      operator = "+",
      value    = { type="variable", name="y" }
    }
  },
  -- 33. nth‐root with index
  {
    input = "\\sqrt[3]{a+b}",
    expected = {
      type     = "sqrt",
      index    = { type="number",   value=3 },
      radicand = {
        type     = "binary",
        operator = "+",
        left     = { type="variable", name="a" },
        right    = { type="variable", name="b" }
      }
    }
  },
}

local passed, failed = 0, 0
for _, t in ipairs(tests) do
  local ast = core.parse(t.input)
  if deep_eq(ast, t.expected) then
    print(("PASS  %q"):format(t.input))
    passed = passed + 1
  else
    print(("FAIL  %q"):format(t.input))
    print("  got:     ", serialize(ast))
    print("  expected:", serialize(t.expected))
    failed = failed + 1
  end
end

print(("\nRESULT: %d passed, %d failed\n"):format(passed, failed))
os.exit(failed > 0 and 1 or 0)
