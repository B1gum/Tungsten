local BaseBackend = {}

function BaseBackend.ast_to_code(ast)
	error("Not implemented")
end

function BaseBackend.ast_to_string(ast)
	error("Not implemented")
end

function BaseBackend.evaluate_async(ast, opts, callback)
	error("Not implemented")
end

function BaseBackend.solve_async(eq_asts, var_asts, is_system, callback)
	error("Not implemented")
end

function BaseBackend.load_handlers()
	error("Not implemented")
end

return BaseBackend
