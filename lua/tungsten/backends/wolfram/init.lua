-- lua/tungsten/backends/wolfram/init.lua
-- Entry point for the Wolfram backend.

local manager = require("tungsten.backends.manager")
local handlers = require("tungsten.backends.wolfram.handlers")
local executor = require("tungsten.backends.wolfram.executor")
local plot = require("tungsten.backends.wolfram.plot_generator")

local M = {
	ast_to_code = executor.ast_to_code,
	evaluate_async = executor.evaluate_async,
	get_persistent_init = executor.get_persistent_init,
	sanitize_persistent_output = executor.sanitize_persistent_output,
	format_persistent_init = executor.format_persistent_init,
	evaluate_persistent = executor.evaluate_persistent,
	solve_async = executor.solve_async,
	load_handlers = handlers.load_handlers,
	reload_handlers = handlers.reload_handlers,
	build_plot_command = plot.build_plot_command,
	plot_async = plot.plot_async,
}

manager.register("wolfram", M)

return M
