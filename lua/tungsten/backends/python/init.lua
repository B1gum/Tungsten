-- lua/tungsten/backends/python/init.lua
-- Entry point for the Python backend.

local manager = require("tungsten.backends.manager")
local handlers = require("tungsten.backends.python.handlers")
local executor = require("tungsten.backends.python.executor")
local plot = require("tungsten.backends.python.plot_generator")

local M = {
	ast_to_code = executor.ast_to_code,
	evaluate_async = executor.evaluate_async,
	get_persistent_init = executor.get_persistent_init,
	format_persistent_init = executor.format_persistent_init,
	evaluate_persistent = executor.evaluate_persistent,
	solve_async = executor.solve_async,
	persistent_write_async = executor.persistent_write_async,
	load_handlers = handlers.load_handlers,
	reload_handlers = handlers.reload_handlers,
	build_plot_command = plot.build_plot_command,
	plot_async = plot.plot_async,
}

manager.register("python", M)

return M
