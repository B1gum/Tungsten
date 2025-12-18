-- core/tokenizer.lua
-- Defines fundamental tokens for parser
------------------------------------------
local lpeg = require("lpeglabel")
local P, R, S, C = lpeg.P, lpeg.R, lpeg.S, lpeg.C

local constants = require("tungsten.core.constants")

local ast = require("tungsten.core.ast")
local latex_spacing = P("\\,")
local whitespace = S(" \t\n\r") + latex_spacing
local space = whitespace ^ 0

local digit = R("09")
local letter = R("az", "AZ")

local number = C(digit ^ 1 * (P(".") * digit ^ 1) ^ -1) / function(n)
	return ast.create_number_node(tonumber(n))
end
local variable = C(letter * (letter + digit) ^ 0)
	/ function(v)
		if constants.is_constant(v) then
			return ast.create_constant_node(v)
		end
		return ast.create_variable_node(v)
	end

local infinity_symbol = P("\\infty") * -letter / function()
	return ast.create_symbol_node("infinity")
end

local greek_list = {
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
local greek_name_patterns = P(false)
for _, name in ipairs(greek_list) do
	greek_name_patterns = greek_name_patterns + P(name)
end
local Greek = P("\\")
	* C(greek_name_patterns)
	* -letter
	/ function(g_name)
		if constants.is_constant(g_name) then
			return ast.create_constant_node(g_name)
		end
		return ast.create_greek_node(g_name)
	end

local matrix_env_name_capture = C(P("pmatrix") + P("bmatrix") + P("vmatrix"))

local matrix_env_begin = P("\\begin{")
	* matrix_env_name_capture
	* P("}")
	/ function(m_type)
		return { type = "matrix_env_begin", env_type = m_type }
	end

local matrix_env_end = P("\\end{")
	* matrix_env_name_capture
	* P("}")
	/ function(m_type)
		return { type = "matrix_env_end", env_type = m_type }
	end

local ampersand = P("&") / function()
	return { type = "ampersand" }
end

local double_backslash = P("\\\\") / function()
	return { type = "double_backslash" }
end

local equals_op = (P("&=") + (P("&") * whitespace ^ 1 * P("=")) + P("="))
	/ function()
		return { type = "equals_op", value = "=" }
	end

local function create_cmd_token(cmd_name_str, token_type_str)
	return P("\\" .. cmd_name_str) * -letter / function()
		return { type = token_type_str }
	end
end

local det_command = create_cmd_token("det", "det_command")
local vec_command = create_cmd_token("vec", "vec_command")
local intercal_command = create_cmd_token("intercal", "intercal_command")
local times_command = create_cmd_token("times", "times_command")

local norm_delimiter_cmd = P("\\|") * -letter / function()
	return { type = "norm_delimiter_cmd" }
end

local double_pipe_norm = P("||") * -P("|") / function()
	return { type = "double_pipe_norm" }
end

local vbar = P("|") * -P("|") / function()
	return { type = "vbar" }
end

local lbrace, rbrace = P("\\left\\{") + P("{"), P("\\right\\}") + P("}")
local lparen, rparen = P("\\left(") + P("("), P("\\right)") + P(")")
local lbrack, rbrack = P("\\left[") + P("["), P("\\right]") + P("]")

local cdot_command = create_cmd_token("cdot", "cdot_command")

return {
	space = space,
	digit = digit,
	letter = letter,
	number = number,
	variable = variable,
	Greek = Greek,
	lbrace = lbrace,
	rbrace = rbrace,
	lparen = lparen,
	rparen = rparen,
	lbrack = lbrack,
	rbrack = rbrack,
	matrix_env_begin = matrix_env_begin,
	matrix_env_end = matrix_env_end,
	matrix_env_name_capture = matrix_env_name_capture,
	ampersand = ampersand,
	double_backslash = double_backslash,
	infinity_symbol = infinity_symbol,
	equals_op = equals_op,
	det_command = det_command,
	vec_command = vec_command,
	intercal_command = intercal_command,
	times_command = times_command,
	norm_delimiter_cmd = norm_delimiter_cmd,
	double_pipe_norm = double_pipe_norm,
	vbar = vbar,
	cdot_command = cdot_command,
}
