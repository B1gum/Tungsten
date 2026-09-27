-- tungsten/lua/tungsten/domains/arithmetic/rules/function_call.lua
local lpeg = vim.lpeg
local P, V, C, Ct, Cg = lpeg.P, lpeg.V, lpeg.C, lpeg.Ct, lpeg.Cg

local tk = require("tungsten.core.tokenizer")
local space = tk.space
local ast = require("tungsten.core.ast")

local ModifiedBesselKind = C(P("I") + P("K"))
local ModifiedBesselOrder = P("_")
	* space
	* Cg(tk.lbrace * space * V("Expression") * space * tk.rbrace + tk.number + tk.variable + tk.Greek, "order")
local ModifiedBesselArg = tk.lparen * space * Cg(V("Expression"), "arg") * space * tk.rparen
local ModifiedBesselCall = Ct(Cg(ModifiedBesselKind, "kind") * ModifiedBesselOrder * ModifiedBesselArg)
	/ function(captures)
		local internal_name = captures.kind == "I" and "besseli" or "besselk"
		return ast.create_function_call_node(ast.create_variable_node(internal_name), { captures.order, captures.arg })
	end

local FunctionName = Cg(tk.variable + tk.Greek, "name_node")
local ArgList = Ct(V("Expression") * (space * P(",") * space * V("Expression")) ^ 0)
local Args = tk.lparen * space * Cg(ArgList, "args") * space * tk.rparen

local FunctionCall = Ct(FunctionName * Args)
	/ function(captures)
		return ast.create_function_call_node(captures.name_node, captures.args)
	end

return ModifiedBesselCall + FunctionCall
