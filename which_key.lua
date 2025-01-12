-- Sets up Which-Key mappings for the plugin.

local wk = require("which-key")

wk.add({
  mode = { "v" },
  { "<leader>w", group = "wolfram" },
  { "<leader>wp", ":<C-u>WolframPlot<CR>", desc = "generate plot (expression [x_min, x_max; y_min, y_max; ...] {legend, red--, 4, -, 3})" },
  { "<leader>we", group = "evaluate" },
  { "<leader>wea", ":<C-u>WolframAutoEval<CR>", desc = "evaluate expression" },
  { "<leader>wen", ":<C-u>WolframAutoEvalNumeric<CR>", desc = "evaluate numerically" },
  { "<leader>weS", ":<C-u>WolframAutoSimplifyNumeric<CR>", desc = "simplify numerically" },
  { "<leader>wes", ":<C-u>WolframAutoSimplify<CR>", desc = "simplify expression" },
  { "<leader>wm", function() require('wolfram_telescope').open_wolfram_picker() end , desc = "open wolfram command palette" },
  { "<leader>ws", group = "solve" },
  { "<leader>ws0", ":<C-u>WolframSolve<CR>", desc = "solve for variable (expression, variable)" },
  { "<leader>wss", ":<C-u>WolframSolveSystem<CR>", desc = "solve system of equations (expression, expression, ...)" },
  { "<leader>wt", ":<C-u>WolframTaylor<CR>", desc = "Taylor series of expression [variable, exp_point, order]"},
  { "<leader>w?", group = "test" },
  { "<leader>w?e", ":<C-u>WolframAutoEvalTest<CR>", desc = "Run WolframAutoEval tests" },
  { "<leader>w?s", ":<C-u>WolframAutoSimplifyTest<CR>", desc = "Run WolframAutoSimplify tests" },
  { "<leader>w?0", group = "solve" },
  { "<leader>w?00", ":<C-u>WolframSolveTest<CR>", desc = "Run WolframSolve tests" },
  { "<leader>w?0e", ":<C-u>WolframSolveSystemTest<CR>", desc = "Run WolframSolveSystem tests" },
  { "<leader>w?p", ":<C-u>WolframPlotTest<CR>", desc = "Run WolframPlot tests" },
  { "<leader>w?t", ":<C-u>WolframTaylorTest<CR>", desc = "Run WolframTaylor tests" },
  { "<leader>w??", "<C-u>WolframAllTests<CR>", desc = "Run all tests"},
})

