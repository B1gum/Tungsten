-- 1. make the project’s `lua/` directory visible to the plain Lua interpreter
package.path = "./lua/?.lua;./lua/?/init.lua;" .. package.path

-- 2. load Tungsten’s parser and code‑generator
local parser   = require "tungsten.core.parser"
local codegen  = require "tungsten.backends.wolfram"

-- 3. helper: strip all insignificant whitespace before comparison
local function normalize(str)
  return (str:gsub("%s+", ""))         -- drop *all* spaces, tabs, newlines
end

-- 4. tests  ── keep them short & decisive
local tests = {
  -- 1. integer literal
  { input = "123",                  expected = "123"},
  -- 2. simple power
  { input = "a^2",                  expected = "a^2"},
  -- 3. fraction
  { input = "\\frac{1}{x+1}",       expected = "1/(x+1)"},
  -- 4. chained add / mul
  { input = "(a+b)\\cdot c",        expected = "(a+b)*c"},
  -- 5. square‑root
  { input    = "\\sqrt{\\sqrt{2}}", expected = "Sqrt[Sqrt[2]]"},
  -- 6. subscript
  { input    = "x_i",               expected = "Subscript[x,i]"},
  -- 7. superscript after subscript
  { input    = "x_i^2",             expected = "Power[Subscript[x,i],2]"},
  -- 8. chained mul / div
  { input    = "a*b/c*d",           expected = "a*b/c*d"},
  -- 9. unary minus
  { input    = "-x",                expected = "-x"},
  -- 10. nth root with index
  { input    = "\\sqrt[3]{a+b}",    expected = "Surd[a+b,3]"},
}

------------------------------------------------------------------
-- 5. test‑runner (same minimal style as in test_core.lua)
------------------------------------------------------------------
local passed, failed = 0, 0

for _, t in ipairs(tests) do
  local ast      = parser.parse(t.input)
  local wl_code  = codegen.to_string(ast)
  if normalize(wl_code) == normalize(t.expected) then
    print(("PASS  %q → %s"):format(t.input, wl_code))
    passed = passed + 1
  else
    print(("FAIL  %q"):format(t.input))
    print("  got:      ", wl_code)
    print("  expected: ", t.expected)
    failed = failed + 1
  end
end

print(("\nRESULT: %d passed, %d failed\n"):format(passed, failed))
os.exit(failed > 0 and 1 or 0)
