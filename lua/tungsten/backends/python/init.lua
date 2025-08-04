-- lua/tungsten/backends/python/init.lua
-- Entry point for the Python backend.

local manager = require("tungsten.backends.manager")
local handlers = require("tungsten.backends.python.handlers")
local executor = require("tungsten.backends.python.executor")

local M = {
	ast_to_code = executor.ast_to_code,
	evaluate_async = executor.evaluate_async,
	solve_async = executor.solve_async,
	load_handlers = handlers.load_handlers,
	reload_handlers = handlers.reload_handlers,
}

manager.register("python", M)

return M
