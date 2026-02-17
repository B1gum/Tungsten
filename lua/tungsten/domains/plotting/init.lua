local lpeg = vim.lpeg
local tokens = require("tungsten.core.tokenizer")
local ast = require("tungsten.core.ast")

local P, V, Ct = lpeg.P, lpeg.V, lpeg.Ct

local function capture_tuple_elements()
	local expr = V("ExpressionContent")
	local comma = tokens.space * P(",") * tokens.space
	return Ct(expr * (comma * expr) ^ 1)
end

local tuple_elements = capture_tuple_elements()

local function tuple_to_point(elements)
	if #elements == 2 then
		return ast.create_point2_node(elements[1], elements[2])
	elseif #elements == 3 then
		return ast.create_point3_node(elements[1], elements[2], elements[3])
	end
	return ast.create_sequence_node(elements)
end

local PointLiteralRule = tokens.lparen * tokens.space * tuple_elements * tokens.space * tokens.rparen / tuple_to_point

local M = {
	name = "plotting",
	priority = 90,
	dependencies = { "arithmetic" },
	overrides = {},
}

M.grammar = { contributions = {}, extensions = {} }

local c = M.grammar.contributions
local prio = M.priority

c[#c + 1] = { name = "PlotPointLiteral", pattern = PointLiteralRule, category = "AtomBaseItem", priority = prio }

local commands = require("tungsten.domains.plotting.commands")
M.commands = commands.commands

return M
