-- tests/unit/core/tokenizer_spec.lua
-- Unit tests for the tokenizer module
---------------------------------------------------------------------

package.path = './lua/?.lua;./lua/?/init.lua;' .. package.path

local lpeg = require "lpeg"
local tokenizer = require("tungsten.core.tokenizer")

describe("tungsten.core.tokenizer", function()
  describe("space token", function()
    it("should match various whitespace combinations", function()
      assert.is_truthy(lpeg.match(tokenizer.space, " "))
      assert.is_truthy(lpeg.match(tokenizer.space, "\t"))
      assert.is_truthy(lpeg.match(tokenizer.space, "\n"))
      assert.is_truthy(lpeg.match(tokenizer.space, "\r"))
      assert.is_truthy(lpeg.match(tokenizer.space, " \t\n\r "))
    end)

    it("should match an empty string (as ^0)", function()
      assert.is_truthy(lpeg.match(tokenizer.space, ""))
    end)

    it("should match at the beginning of a string with other characters", function()
      assert.is_truthy(lpeg.match(tokenizer.space * lpeg.P(1), " test"))
    end)

    it("should match at the end of a string with other characters", function()
      assert.is_truthy(lpeg.match(lpeg.P(1) * tokenizer.space, "test "))
    end)
  end)

  describe("number token", function()
    it("should match integers and produce correct AST node", function()
      local input = "123"
      local expected_ast = { type = "number", value = 123 }
      assert.are.same(expected_ast, lpeg.match(tokenizer.number, input))
    end)

    it("should match numbers with decimals and produce correct AST node", function()
      local input = "1.23"
      local expected_ast = { type = "number", value = 1.23 }
      assert.are.same(expected_ast, lpeg.match(tokenizer.number, input))
    end)

    it("should match '0.5' and produce correct AST node", function()
      local input = "0.5"
      local expected_ast = { type = "number", value = 0.5 }
      assert.are.same(expected_ast, lpeg.match(tokenizer.number, input))
    end)

    it("should match '0' and produce correct AST node", function()
      local input = "0"
      local expected_ast = { type = "number", value = 0 }
      assert.are.same(expected_ast, lpeg.match(tokenizer.number, input))
    end)

    it("should not match numbers starting with a decimal point (e.g., '.5')", function()
      assert.is_nil(lpeg.match(tokenizer.number, ".5"))
    end)

    it("should not match empty string", function()
      assert.is_nil(lpeg.match(tokenizer.number, ""))
    end)

    it("should not match strings with only spaces", function()
      assert.is_nil(lpeg.match(tokenizer.number, "   "))
    end)

    it("should only match the number part if followed by other characters", function()
        local pattern_to_test = tokenizer.number * lpeg.C(lpeg.P(1)^0)
        local input = "123test"
        local ast_node, rest_str = lpeg.match(pattern_to_test, input)
        assert.are.same({type = "number", value = 123}, ast_node)
        assert.are.equal("test", rest_str)
    end)

    it("should match '12.34' and produce correct AST node", function()
      local input = "12.34"
      local expected_ast = { type = "number", value = 12.34 }
      assert.are.same(expected_ast, lpeg.match(tokenizer.number, input))
    end)
  end)

  describe("variable token", function()
    it("should match single letters and produce correct AST node", function()
      local input = "x"
      local expected_ast = { type = "variable", name = "x" }
      assert.are.same(expected_ast, lpeg.match(tokenizer.variable, input))
    end)

    it("should match multi-character alphanumeric strings starting with a letter and produce correct AST node", function()
      local input = "var1"
      local expected_ast = { type = "variable", name = "var1" }
      assert.are.same(expected_ast, lpeg.match(tokenizer.variable, input))
    end)

    it("should match multi-character strings with only letters", function()
      local input = "variableName"
      local expected_ast = { type = "variable", name = "variableName" }
      assert.are.same(expected_ast, lpeg.match(tokenizer.variable, input))
    end)

    it("should not match strings starting with a digit", function()
      assert.is_nil(lpeg.match(tokenizer.variable, "1var"))
    end)

    it("should not match empty string", function()
      assert.is_nil(lpeg.match(tokenizer.variable, ""))
    end)

    it("should not match strings with only spaces", function()
      assert.is_nil(lpeg.match(tokenizer.variable, "   "))
    end)

    it("should only match the variable part if followed by non-alphanumeric characters", function()
        local pattern_to_test = tokenizer.variable * lpeg.C(lpeg.P(1)^0)
        local input = "myVar+more"
        local ast_node, rest_str = lpeg.match(pattern_to_test, input)
        assert.are.same({type = "variable", name = "myVar"}, ast_node)
        assert.are.equal("+more", rest_str)
    end)
  end)

  describe("Greek token", function()
    local greek_letters_to_test = { "alpha", "beta", "gamma", "delta", "epsilon", "zeta", "eta", "theta", "iota", "kappa", "lambda", "mu", "nu", "xi", "pi", "rho", "sigma", "tau", "upsilon", "phi", "chi", "psi", "omega" }

    for _, letter_name in ipairs(greek_letters_to_test) do
      it("should match '\\" .. letter_name .. "' and produce correct AST node", function()
        local input = "\\" .. letter_name
        local expected_ast = { type = "greek", name = letter_name }
        assert.are.same(expected_ast, lpeg.match(tokenizer.Greek, input))
      end)
    end

    it("should not match invalid or incomplete Greek commands", function()
      assert.is_nil(lpeg.match(tokenizer.Greek, "\\alp"))
      assert.is_nil(lpeg.match(tokenizer.Greek, "alpha"))
      assert.is_nil(lpeg.match(tokenizer.Greek, "\\Alpha"))
      assert.is_nil(lpeg.match(tokenizer.Greek, "\\ gamma"))
    end)

    it("should not match empty string", function()
      assert.is_nil(lpeg.match(tokenizer.Greek, ""))
    end)

    it("should not match strings with only spaces", function()
      assert.is_nil(lpeg.match(tokenizer.Greek, "   "))
    end)

    it("should only match the Greek token part if followed by other characters", function()
        local pattern_to_test = tokenizer.Greek * lpeg.C(lpeg.P(1)^0)
        local input = "\\alpha+1"
        local ast_node, rest_str = lpeg.match(pattern_to_test, input)
        assert.are.same({type = "greek", name = "alpha"}, ast_node)
        assert.are.equal("+1", rest_str)
    end)
  end)

  describe("Bracket tokens", function()
    it("lbrace should match '{'", function()
      assert.is_truthy(lpeg.match(tokenizer.lbrace, "{"))
      assert.is_nil(lpeg.match(tokenizer.lbrace, "}"))
    end)

    it("rbrace should match '}'", function()
      assert.is_truthy(lpeg.match(tokenizer.rbrace, "}"))
      assert.is_nil(lpeg.match(tokenizer.rbrace, "{"))
    end)

    it("lparen should match '('", function()
      assert.is_truthy(lpeg.match(tokenizer.lparen, "("))
      assert.is_nil(lpeg.match(tokenizer.lparen, ")"))
    end)

    it("rparen should match ')'", function()
      assert.is_truthy(lpeg.match(tokenizer.rparen, ")"))
      assert.is_nil(lpeg.match(tokenizer.rparen, "("))
    end)

    it("lbrack should match '['", function()
      assert.is_truthy(lpeg.match(tokenizer.lbrack, "["))
      assert.is_nil(lpeg.match(tokenizer.lbrack, "]"))
    end)

    it("rbrack should match ']'", function()
      assert.is_truthy(lpeg.match(tokenizer.rbrack, "]"))
      assert.is_nil(lpeg.match(tokenizer.rbrack, "["))
    end)

    it("bracket tokens should only match their respective characters", function()
        local brackets = {
            {pattern = tokenizer.lbrace, char = "{", non_char = "("},
            {pattern = tokenizer.rbrace, char = "}", non_char = ")"},
            {pattern = tokenizer.lparen, char = "(", non_char = "["},
            {pattern = tokenizer.rparen, char = ")", non_char = "]"},
            {pattern = tokenizer.lbrack, char = "[", non_char = "{"},
            {pattern = tokenizer.rbrack, char = "]", non_char = "}"},
        }
        for _, b in ipairs(brackets) do
            assert.is_truthy(lpeg.match(b.pattern, b.char), "Pattern for " .. b.char .. " failed to match.")
            assert.is_nil(lpeg.match(b.pattern, b.non_char), "Pattern for " .. b.char .. " incorrectly matched " .. b.non_char)
            assert.is_nil(lpeg.match(b.pattern, "a"), "Pattern for " .. b.char .. " incorrectly matched 'a'")
            assert.is_nil(lpeg.match(b.pattern, ""), "Pattern for " .. b.char .. " incorrectly matched empty string")
        end
    end)
  end)
end)
