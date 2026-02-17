local lpeg = vim.lpeg
local P = lpeg.P
local ast = require("tungsten.core.ast")
local tk = require("tungsten.core.tokenizer")

local AngCmd = P("\\ang")

local LBrace = tk.lbrace
local RBrace = tk.rbrace

local Content = lpeg.R("09") ^ 1 * (P(".") * lpeg.R("09") ^ 1) ^ -1 / tonumber / ast.create_number_node

local AngRule = AngCmd * tk.space * LBrace * tk.space * Content * tk.space * RBrace / ast.create_angle_node

return AngRule
