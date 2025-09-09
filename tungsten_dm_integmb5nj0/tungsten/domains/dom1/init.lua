return {
	name = "dom1",
	priority = 10,
	grammar = { contributions = { { name = "Num", pattern = "p1", category = "AtomBaseItem" } }, extensions = {} },
	commands = { {
		name = "Dom1Cmd",
		func = function()
			_G.dom1_commands_called = true
		end,
		opts = {},
	} },
	handlers = function()
		_G.dom1_handlers_called = true
	end,
}
