--------------------------------------------------------------------------------
-- which_key.lua
-- Sets up Which-Key mappings for the plugin.
--------------------------------------------------------------------------------

local wk = require("which-key")

wk.add({
  mode = { "v" },
  { "<leader>t", group = "tungsten" },
  { "<leader>tp", ":<C-u>TungstenPlot<CR>", desc = "generate plot (expression [x_min, x_max; y_min, y_max; ...] {legend, red--, 4, -, 3})" },
  { "<leader>te", group = "evaluate" },
  { "<leader>tea", ":<C-u>TungstenAutoEval<CR>", desc = "evaluate expression" },
  { "<leader>ten", ":<C-u>TungstenAutoEvalNumeric<CR>", desc = "evaluate numerically" },
  { "<leader>teS", ":<C-u>TungstenAutoSimplifyNumeric<CR>", desc = "simplify numerically" },
  { "<leader>tes", ":<C-u>TungstenAutoSimplify<CR>", desc = "simplify expression" },
  { "<leader>tm", function() require("tungsten.telescope").open_tungsten_picker() end, desc = "open tungsten command palette" },
  { "<leader>ts", group = "solve" },
  { "<leader>ts0", ":<C-u>TungstenSolve<CR>", desc = "solve for variable (expression, variable)" },
  { "<leader>tss", ":<C-u>TungstenSolveSystem<CR>", desc = "solve system of equations (expression, expression, ...)" },
  { "<leader>tt", ":<C-u>TungstenTaylor<CR>", desc = "Taylor series of expression [variable, exp_point, order]"},
  { "<leader>t?", group = "test" },
  { "<leader>t?e", ":<C-u>TungstenAutoEvalTest<CR>", desc = "Run TungstenAutoEval tests" },
  { "<leader>t?s", ":<C-u>TungstenAutoSimplifyTest<CR>", desc = "Run TungstenAutoSimplify tests" },
  { "<leader>t?0", group = "solve" },
  { "<leader>t?00", ":<C-u>TungstenSolveTest<CR>", desc = "Run TungstenSolve tests" },
  { "<leader>t?0e", ":<C-u>TungstenSolveSystemTest<CR>", desc = "Run TungstenSolveSystem tests" },
  { "<leader>t?t", ":<C-u>TungstenTaylorTest<CR>", desc = "Run TungstenTaylor tests" },
  { "<leader>t?u",
    function()
      -- Prompt for the suite name (or "all")
      local suite = vim.fn.input("Test Suite (or 'all'): ")
      if suite == "" then
        return
      end

      if suite == "all" then
        -- Run the old :TungstenUnitTests command
        vim.cmd("TungstenUnitTests")
      else
        -- Run :TungstenTestSuite <suite>
        vim.cmd("TungstenTestSuite " .. suite)
      end
    end,
    desc = "run single unit test" },
  { "<leader>t??", "<C-u>TungstenAllTests<CR>", desc = "Run all tests"},
})

