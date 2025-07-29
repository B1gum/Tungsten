-- lua/tungsten/domains/linear_algebra/rules/vector.lua
-- Defines the lpeg rule for parsing \vec, \mathbf vector notations, and lists of vectors.

local lpeg = require("lpeglabel")
local P, V, Ct = lpeg.P, lpeg.V, lpeg.Ct

local tk = require("tungsten.core.tokenizer")
local ast = require("tungsten.core.ast")
local space = tk.space

local SymbolicVecCommand = P("\\vec")
	* space
	* tk.lbrace
	* space
	* V("Expression")
	* space
	* tk.rbrace
	/ function(expr_capture)
		return ast.create_symbolic_vector_node(expr_capture, "vec")
	end

local SymbolicMathBoldCommand = P("\\mathbf")
	* space
	* tk.lbrace
	* space
	* V("Expression")
	* space
	* tk.rbrace
	/ function(expr_capture)
		return ast.create_symbolic_vector_node(expr_capture, "mathbf")
	end

local SingleSymbolicVectorRule = SymbolicVecCommand + SymbolicMathBoldCommand

local ConcreteVectorRule = V("Matrix") / function(matrix_ast)
	return matrix_ast
end

local VectorListItem = space * (SingleSymbolicVectorRule + ConcreteVectorRule) * space
local VectorListRule = Ct(VectorListItem * (P(";") * VectorListItem) ^ 0)
	/ function(vector_asts)
		if #vector_asts == 1 and vector_asts[1].type ~= "matrix" then
			return vector_asts[1]
		elseif #vector_asts == 1 and vector_asts[1].type == "matrix" then
			return vector_asts[1]
		end
		return ast.create_vector_list_node(vector_asts)
	end

local FinalVectorRule = VectorListRule + SingleSymbolicVectorRule + ConcreteVectorRule

return FinalVectorRule
