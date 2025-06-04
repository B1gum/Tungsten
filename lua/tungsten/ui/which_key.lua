-- which_key.lua
-- Module for which_key integration
-------------------------------------------------------------------------------------------

local wk = require "which-key"

wk.add({
  mode = { "v" },
  {
    "<leader>t",
    group = "tungsten",
  },
  {
    "<leader>tm",
    function()
      require("tungsten.ui").open()
    end,
    desc = "open tungsten command palette",
  },
  {
    "<leader>te",
    group = "evaluate",
  },
  {
    "<leader>tee",
    ":<C-u>TungstenEvaluate<CR>",
    desc = "Evaluate Expression",
  },
  {
    "<leader>td",
    ":<C-u>TungstenDefinePersistentVariable<CR>",
    desc = "Define Persistent Variable",
  },
  {
    "<leader>ts",
    ":<C-u>TungstenSolve<CR>",
    desc = "Define Persistent Variable",
  },
  {
    "<leader>tg",
    ":<C-u>TungstenGaussEliminate<CR>",
    desc = "Gauss Eliminate",
  },
})
