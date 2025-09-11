-- lua/tungsten/backends/capabilities.lua
-- Defines plotting capability matrix for available backends

local backend_capabilities = {
	wolfram = {
		name = "wolfram",
		supports = {
			explicit = { [2] = true, [3] = true },
			implicit = { [2] = true, [3] = true },
			parametric = { [2] = true, [3] = true },
			polar = { [2] = true },
			points = {},
			inequalities = { [2] = true, [3] = true },
		},
	},
	python = {
		name = "python",
		supports = {
			explicit = { [2] = true, [3] = true },
			implicit = { [2] = true },
			parametric = { [2] = true, [3] = true },
			polar = { [2] = true },
			points = {},
			inequalities = {},
		},
	},
}

return backend_capabilities
