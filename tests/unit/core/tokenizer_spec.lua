-- tests/unit/core/tokenizer_spec.lua
-- Unit tests for the tokenizer module

local lpeg = vim.lpeg
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
			local pattern_to_test = tokenizer.number * lpeg.C(lpeg.P(1) ^ 0)
			local input = "123test"
			local ast_node, rest_str = lpeg.match(pattern_to_test, input)
			assert.are.same({ type = "number", value = 123 }, ast_node)
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

		it(
			"should match multi-character alphanumeric strings starting with a letter and produce correct AST node",
			function()
				local input = "var1"
				local expected_ast = { type = "variable", name = "var1" }
				assert.are.same(expected_ast, lpeg.match(tokenizer.variable, input))
			end
		)

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
			local pattern_to_test = tokenizer.variable * lpeg.C(lpeg.P(1) ^ 0)
			local input = "myVar+more"
			local ast_node, rest_str = lpeg.match(pattern_to_test, input)
			assert.are.same({ type = "variable", name = "myVar" }, ast_node)
			assert.are.equal("+more", rest_str)
		end)
	end)

	describe("Greek token", function()
		local greek_letters_to_test = {
			"alpha",
			"beta",
			"gamma",
			"delta",
			"epsilon",
			"zeta",
			"eta",
			"theta",
			"iota",
			"kappa",
			"lambda",
			"mu",
			"nu",
			"xi",
			"pi",
			"rho",
			"sigma",
			"tau",
			"upsilon",
			"phi",
			"chi",
			"psi",
			"omega",
		}

		for _, letter_name in ipairs(greek_letters_to_test) do
			it("should match '\\" .. letter_name .. "' and produce correct AST node", function()
				local input = "\\" .. letter_name
				local expected_ast = { type = "greek", name = letter_name }
				if letter_name == "pi" then
					expected_ast = { type = "constant", name = "pi" }
				end
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
			local pattern_to_test = tokenizer.Greek * lpeg.C(lpeg.P(1) ^ 0)
			local input = "\\alpha+1"
			local ast_node, rest_str = lpeg.match(pattern_to_test, input)
			assert.are.same({ type = "greek", name = "alpha" }, ast_node)
			assert.are.equal("+1", rest_str)
		end)
	end)

	describe("Infinity symbol token", function()
		it("should match \\infty and produce a symbol AST node", function()
			local input = "\\infty"
			local expected_ast = { type = "symbol", name = "infinity" }
			assert.are.same(expected_ast, lpeg.match(tokenizer.infinity_symbol, input))
		end)

		it("should not match partial or suffixed commands", function()
			assert.is_nil(lpeg.match(tokenizer.infinity_symbol, "\\inf"))
			assert.is_nil(lpeg.match(tokenizer.infinity_symbol, "\\inftyExtra"))
		end)

		it("should only consume the infinity token when followed by other text", function()
			local pattern_to_test = tokenizer.infinity_symbol * lpeg.C(lpeg.P(1) ^ 0)
			local ast_node, rest_str = lpeg.match(pattern_to_test, "\\infty+1")
			assert.are.same({ type = "symbol", name = "infinity" }, ast_node)
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
				{ pattern = tokenizer.lbrace, char = "{", non_char = "(" },
				{ pattern = tokenizer.rbrace, char = "}", non_char = ")" },
				{ pattern = tokenizer.lparen, char = "(", non_char = "[" },
				{ pattern = tokenizer.rparen, char = ")", non_char = "]" },
				{ pattern = tokenizer.lbrack, char = "[", non_char = "{" },
				{ pattern = tokenizer.rbrack, char = "]", non_char = "}" },
			}
			for _, b in ipairs(brackets) do
				assert.is_truthy(lpeg.match(b.pattern, b.char), "Pattern for " .. b.char .. " failed to match.")
				assert.is_nil(
					lpeg.match(b.pattern, b.non_char),
					"Pattern for " .. b.char .. " incorrectly matched " .. b.non_char
				)
				assert.is_nil(lpeg.match(b.pattern, "a"), "Pattern for " .. b.char .. " incorrectly matched 'a'")
				assert.is_nil(lpeg.match(b.pattern, ""), "Pattern for " .. b.char .. " incorrectly matched empty string")
			end
		end)
	end)

	describe("Matrix Environment Tokens", function()
		describe("matrix_env_begin token", function()
			local env_types = { "pmatrix", "bmatrix", "vmatrix" }
			for _, env_type in ipairs(env_types) do
				it("should match '\\begin{" .. env_type .. "}' and produce correct AST node", function()
					local input = "\\begin{" .. env_type .. "}"
					local expected_ast = { type = "matrix_env_begin", env_type = env_type }
					assert.are.same(expected_ast, lpeg.match(tokenizer.matrix_env_begin, input))
				end)
			end

			it("should not match invalid or incomplete matrix begin commands", function()
				assert.is_nil(lpeg.match(tokenizer.matrix_env_begin, "\\begin{matrix}"))
				assert.is_nil(lpeg.match(tokenizer.matrix_env_begin, "\\begin{pmatrix"))
				assert.is_nil(lpeg.match(tokenizer.matrix_env_begin, "begin{pmatrix}"))
				assert.is_nil(lpeg.match(tokenizer.matrix_env_begin, "\\begin pmatrix}"))
			end)

			it("should only match the token part if followed by other characters", function()
				local pattern_to_test = tokenizer.matrix_env_begin * lpeg.C(lpeg.P(1) ^ 0)
				local input = "\\begin{pmatrix}rest"
				local ast_node, rest_str = lpeg.match(pattern_to_test, input)
				assert.are.same({ type = "matrix_env_begin", env_type = "pmatrix" }, ast_node)
				assert.are.equal("rest", rest_str)
			end)
		end)

		describe("matrix_env_end token", function()
			local env_types = { "pmatrix", "bmatrix", "vmatrix" }
			for _, env_type in ipairs(env_types) do
				it("should match '\\end{" .. env_type .. "}' and produce correct AST node", function()
					local input = "\\end{" .. env_type .. "}"
					local expected_ast = { type = "matrix_env_end", env_type = env_type }
					assert.are.same(expected_ast, lpeg.match(tokenizer.matrix_env_end, input))
				end)
			end

			it("should not match invalid or incomplete matrix end commands", function()
				assert.is_nil(lpeg.match(tokenizer.matrix_env_end, "\\end{matrix}"))
				assert.is_nil(lpeg.match(tokenizer.matrix_env_end, "\\end{pmatrix"))
				assert.is_nil(lpeg.match(tokenizer.matrix_env_end, "end{pmatrix}"))
				assert.is_nil(lpeg.match(tokenizer.matrix_env_end, "\\end pmatrix}"))
			end)
		end)
	end)

	describe("Matrix Element Separator Tokens", function()
		describe("ampersand token", function()
			it("should match '&' and produce correct AST node", function()
				local input = "&"
				local expected_ast = { type = "ampersand" }
				assert.are.same(expected_ast, lpeg.match(tokenizer.ampersand, input))
			end)

			it("should not match other characters", function()
				assert.is_nil(lpeg.match(tokenizer.ampersand, "a"))
				assert.is_nil(lpeg.match(tokenizer.ampersand, "\\"))
			end)
		end)

		describe("double_backslash token", function()
			it("should match '\\\\' and produce correct AST node", function()
				local input = "\\\\"
				local expected_ast = { type = "double_backslash" }
				assert.are.same(expected_ast, lpeg.match(tokenizer.double_backslash, input))
			end)

			it("should not match single backslash or other characters", function()
				assert.is_nil(lpeg.match(tokenizer.double_backslash, "\\"))
				assert.is_nil(lpeg.match(tokenizer.double_backslash, "a\\"))
			end)
		end)
	end)

	describe("Specific LaTeX Command Tokens", function()
		local commands_to_test = {
			{ name = "det", token_name = "det_command", pattern = tokenizer.det_command },
			{ name = "vec", token_name = "vec_command", pattern = tokenizer.vec_command },
			{ name = "intercal", token_name = "intercal_command", pattern = tokenizer.intercal_command },
			{ name = "times", token_name = "times_command", pattern = tokenizer.times_command },
			{ name = "\\|", token_name = "norm_delimiter_cmd", pattern = tokenizer.norm_delimiter_cmd, is_raw_name = true },
		}

		for _, cmd_info in ipairs(commands_to_test) do
			local display_name = cmd_info.is_raw_name and cmd_info.name or ("\\" .. cmd_info.name)
			describe(cmd_info.token_name .. " ('" .. display_name .. "')", function()
				it("should match '" .. display_name .. "' and produce correct AST node", function()
					local input = display_name
					local expected_ast = { type = cmd_info.token_name }
					assert.are.same(expected_ast, lpeg.match(cmd_info.pattern, input))
				end)

				it("should not match incomplete or incorrect commands", function()
					if not cmd_info.is_raw_name then
						assert.is_nil(lpeg.match(cmd_info.pattern, "\\" .. cmd_info.name:sub(1, -2)))
						assert.is_nil(lpeg.match(cmd_info.pattern, cmd_info.name))
						assert.is_nil(lpeg.match(cmd_info.pattern, "\\" .. cmd_info.name .. "extra"))
					else
						assert.is_nil(lpeg.match(cmd_info.pattern, cmd_info.name:sub(1, -2)))
					end
					assert.is_nil(lpeg.match(cmd_info.pattern, "random"))
				end)

				it("should only match the token part if followed by other characters", function()
					local pattern_to_test = cmd_info.pattern * lpeg.C(lpeg.P(1) ^ 0)
					local input = display_name .. "{arg}"
					local ast_node, rest_str = lpeg.match(pattern_to_test, input)
					assert.are.same({ type = cmd_info.token_name }, ast_node)
					assert.are.equal("{arg}", rest_str)
				end)
			end)
		end
	end)

	describe("double_pipe_norm token", function()
		it("should match '||' and produce correct AST node", function()
			local input = "||"
			local expected_ast = { type = "double_pipe_norm" }
			assert.are.same(expected_ast, lpeg.match(tokenizer.double_pipe_norm, input))
		end)

		it("should not match single pipe or other characters", function()
			assert.is_nil(lpeg.match(tokenizer.double_pipe_norm, "|"))
			assert.is_nil(lpeg.match(tokenizer.double_pipe_norm, "|a|"))
			assert.is_nil(lpeg.match(tokenizer.double_pipe_norm, "|||"))
		end)

		it("should only match the token part if followed by other characters", function()
			local pattern_to_test = tokenizer.double_pipe_norm * lpeg.C(lpeg.P(1) ^ 0)
			local input = "||x||"
			local ast_node, rest_str = lpeg.match(pattern_to_test, input)
			assert.are.same({ type = "double_pipe_norm" }, ast_node)
			assert.are.equal("x||", rest_str)
		end)
	end)
end)
