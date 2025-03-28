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
      require("tungsten.telescope").open_tungsten_picker()
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
    ":<C-u>TungstenParserTest<CR>",
  },
})
