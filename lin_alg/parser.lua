--------------------------------------------------------------------------------
-- parser.lua
-- Parses expressions with matrices.
--------------------------------------------------------------------------------

local M = {}

-- 1) High-level cleanup to remove newlines and trim spacing
function M.high_level_cleanup(expr)
  -- Basic "cleaning" steps, example:
  expr = expr:gsub("\n", " ")    -- Replace line breaks with spaces
  expr = expr:gsub("%s+", " ")   -- Compact multiple spaces
  return expr
end

-- 2) Convert LaTeX pmatrix -> Wolfram's {{...}, {...}}
--    This returns:
--      replaced_expr = the original string but with placeholders:  M_1, M_2, ...
--      replacements  = { ["M_1"] = "{{...}}", ["M_2"] = "{{...}}", ... }
local function extract_matrices(expr)
  local replacements = {}
  local idx = 0

  local function convert_pmatrix_to_wolfram(pmatrix_content)

    -- remove trailing backslashes/spaces
    pmatrix_content = pmatrix_content:gsub("\\%s*$", "")

    -- Split by rows: `\\`
    local rows = {}
    for row in pmatrix_content:gmatch("([^\\]+)") do
      row = row:gsub("^%s+", ""):gsub("%s+$", "")  -- trim
      table.insert(rows, row)
    end

    local wolfram_rows = {}
    for _, row_str in ipairs(rows) do
      local cols = {}
      for col in row_str:gmatch("([^&]+)") do
        col = col:gsub("^%s+", ""):gsub("%s+$", "") -- trim
        table.insert(cols, col)
      end
      table.insert(wolfram_rows, "{" .. table.concat(cols, ", ") .. "}")
    end

    return "{" .. table.concat(wolfram_rows, ", ") .. "}"
  end

  -- Replace each \begin{pmatrix} ... \end{pmatrix} with "M_i"
  local result = expr:gsub("\\begin%{pmatrix%}(.-)\\end%{pmatrix%}", function(content)
    idx = idx + 1
    local placeholder = "M_" .. idx
    replacements[placeholder] = convert_pmatrix_to_wolfram(content)
    return placeholder
  end)

  return result, replacements
end

-- 3) Tokenize the placeholders, operators, parentheses, etc.
--    Then we re-insert the actual Wolfram matrix strings, while
--    converting adjacency into multiplication (e.g. "M_1 M_2" => "M_1 . M_2").
--    Also replace "\cdot" with '.' (Wolfram matrix multiply).
local function build_wolfram_expression(expr_with_placeholders, replacements)
  -- We'll do a simple token pass. You can refine if needed.
  -- 1. Insert spacing around parentheses, +, -, etc. so we can split easily.
  local spaced = expr_with_placeholders
    :gsub("([%+%-%(%)])", " %1 ")
    :gsub("\\cdot", " . ")   -- If user wrote "\cdot" => . 
    :gsub("%s+", " ")         -- cleanup

  local tokens = {}
  for word in spaced:gmatch("%S+") do
    table.insert(tokens, word)
  end

  -- 2. Insert multiplication '.' if two placeholders are adjacent,
  --    or if a placeholder is followed by '(' or vice versa.
  --    In Wolfram, for matrix multiplication, we typically do: A . B
  --    (But if you're comfortable with just `A B` => A*B, you can skip the dot).
  local final_tokens = {}
  local N = #tokens
  for i, token in ipairs(tokens) do
    table.insert(final_tokens, token)

    if i < N then
      local next_token = tokens[i+1]
      -- if current token is M_x (or a parenthesis) and next token is M_x or '(',
      -- then we assume implicit multiplication => '.'.
      local curr_is_matrix = token:match("^M_%d+$")
      local next_is_matrix = next_token:match("^M_%d+$")
      local curr_is_paren_close = (token == ")")
      local next_is_paren_open  = (next_token == "(")

      -- Condition for adjacency => insert '.' or '.' (your choice).
      if (curr_is_matrix and next_is_matrix)
         or (curr_is_matrix and next_is_paren_open)
         or (curr_is_paren_close and next_is_matrix) then

         table.insert(final_tokens, ".")
      end
    end
  end

  -- 3. Rebuild them into a single string
  local wolfram_expr = table.concat(final_tokens, " ")

  -- 4. Finally, replace M_x placeholders with their actual Wolfram matrix strings
  for placeholder, matrix_str in pairs(replacements) do
    -- Make sure we do a safe gsub; the placeholder is distinct enough (M_1, etc.)
    wolfram_expr = wolfram_expr:gsub(placeholder, matrix_str)
  end

  return wolfram_expr
end

-- 4) The main function to parse *any* matrix-based expression, detecting
--    +, -, parentheses, etc., returning a valid Wolfram expression
function M.parse_linear_algebra_expr(expr)
  local expr_with_placeholders, replacements = extract_matrices(expr)
  local wolfram_expr = build_wolfram_expression(expr_with_placeholders, replacements)
  return wolfram_expr
end

-------------------------------------------------------------------------------
-- Example: parse_result (unchanged, presumably):
-------------------------------------------------------------------------------
function M.parse_result(raw_result)
  -- Suppose you do something to remove TeX-form headers, etc.
  local cleaned = raw_result:gsub("%$+", "") -- remove extraneous $ if present
  return cleaned
end

return M
