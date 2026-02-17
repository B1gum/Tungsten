-- tungsten/lua/tungsten/domains/linear_algebra/rules/rank.lua
-- Defines the lpeg rule for parsing rank expressions like \mathrm{rank}(A) or \text{rank}(A)

local lpeg = vim.lpeg
local P, V, Cg, Ct = lpeg.P, lpeg.V, lpeg.Cg, lpeg.Ct

local tk = require("tungsten.core.tokenizer")
local space = tk.space
local ast = require("tungsten.core.ast")

local rank_command_str = P("\\mathrm{rank}") + P("\\text{rank}")

local open_paren = tk.lparen + P("\\left(")
local close_paren = tk.rparen + P("\\right)")

local RankRule = Ct(
	rank_command_str * space * open_paren * space * Cg(V("Expression"), "matrix_expr") * space * close_paren * space
) / function(captures)
	return ast.create_rank_node(captures.matrix_expr)
end

return RankRule
