local BaseBackend = {}

function BaseBackend.ast_to_code(_ast)
	error("Not implemented")
end

function BaseBackend.ast_to_string(_ast)
	error("Not implemented")
end

function BaseBackend.evaluate_async(_ast, _opts, _callback)
	error("Not implemented")
end

function BaseBackend.solve_async(_eq_asts, _var_asts, _is_system, _callback)
	error("Not implemented")
end

function BaseBackend.load_handlers(_domains, _registry)
	error("Not implemented")
end

return BaseBackend
