-- which_key.lua
-- Module for which_key integration
-------------------------------------------------------------------------------------------

local wk = require("which-key")

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
    ":<C-u>TungstenEval<CR>",
  },
  {
    "<leader>t?",
    group = "tests",
  },
  {
    "<leader>t?p",
    ":<C-u>TungstenParserTestCore<CR>",
  },
})
