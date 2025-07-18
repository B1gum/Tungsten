-- tungsten/lua/tungsten/domains/arithmetic/rules/function_call.lua
local lpeg = require("lpeglabel")
local P, V, Ct, Cg = lpeg.P, lpeg.V, lpeg.Ct, lpeg.Cg

local tk = require("tungsten.core.tokenizer")
local space = tk.space
local ast = require("tungsten.core.ast")

local FunctionName = Cg(tk.variable, "name_node")
local ArgList = Ct(V("Expression") * (space * P(",") * space * V("Expression")) ^ 0)
local Args = tk.lparen * space * Cg(ArgList, "args") * space * tk.rparen

local FunctionCall = Ct(FunctionName * Args)
	/ function(captures)
		return ast.create_function_call_node(captures.name_node, captures.args)
	end

return FunctionCall
