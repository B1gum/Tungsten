--------------------------------------------------------------------------------
-- validation.lua
-- Simple module for validating results
--------------------------------------------------------------------------------

local M = {}

function M.is_balanced(str)
  local stack = {}
  local pairs = { ["("] = ")", ["{"] = "}", ["["] = "]" }   -- Maps each opening bracket to the corresponding closing bracket
  for i = 1, #str do                                        -- Loop through all the characters in the string
    local c = str:sub(i,i)                                  -- Retrieve the current character
    if pairs[c] then                                        -- If the current character is an opening bracket, then
      table.insert(stack, pairs[c])                         -- Push the corresponding closing bracket into the stack
    elseif c == ")" or c == "}" or c == "]" then            -- If c is a closing bracket, then
      local expected = table.remove(stack)                  -- pop the last expected closing bracket from the stack
      if c ~= expected then                                 -- If the popped bracket does not match c then
        return false                                        -- return false
      end
    end
  end
  return #stack == 0                                        -- If the stack is empty after the loop then the check passed
end

return M
