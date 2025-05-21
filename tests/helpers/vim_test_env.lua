-- tests/helpers/vim_test_env.lua
local spy = require 'luassert.spy'

local M = {}

local original_vim_global = _G.vim
local original_pcall_global = _G.pcall

local inspect_fallback = function(obj, opts)
  opts = opts or {}
  local to_string_lookup = {}
  local function do_inspect(current_obj, current_depth)
    if current_obj == nil then return "nil" end
    local t = type(current_obj)
    if t == "string" then return string.format("%q", current_obj)
    elseif t == "number" or t == "boolean" or t == "function" then return tostring(current_obj)
    elseif t == "table" then
      if current_depth <= 0 then return "{...}" end
      if to_string_lookup[current_obj] then return "{recursive}" end
      to_string_lookup[current_obj] = true
      local parts = {}
      for k, v in pairs(current_obj) do
        table.insert(parts, string.format("%s = %s", tostring(k), do_inspect(v, current_depth - 1)))
      end
      to_string_lookup[current_obj] = false
      return "{ " .. table.concat(parts, ", ") .. " }"
    else return t .. ": " .. tostring(current_obj) end
  end
  return do_inspect(obj, opts.depth or 3)
end

local mock_rtp_components = {
  ["/tmp/nvim-mock-data/site"] = true,
  ["/tmp/nvim-mock-data/user-plugin"] = true,
  ["/tmp/nvim-mock-data/site/after"] = true,
}

M.mocked_vim = {
  api = {
    nvim_create_user_command = spy.new(function() end),
    nvim_get_current_buf = spy.new(function() return 1 end),
    nvim_buf_get_lines = spy.new(function() return {} end),
    nvim_buf_set_lines = spy.new(function() end),
    nvim_create_namespace = spy.new(function(name) return 1000 end),
    nvim_echo = spy.new(function() end),
    nvim_err_writeln = spy.new(function(...) print("ERROR:", ...) end),
    nvim_get_option_value = spy.new(function(name, opts)
      if name == 'runtimepath' or name == 'packpath' then
        return "/tmp/nvim-mock-data/site,/tmp/nvim-mock-data/user-plugin,/tmp/nvim-mock-data/site/after"
      end
      return nil
    end),
    nvim_list_uis = spy.new(function() return {} end),
    nvim_get_mode = spy.new(function() return { mode = "n", blocking = false } end),
    nvim__get_runtime = spy.new(function() return {} end),
  },
  fn = {
    jobstart = spy.new(function() return 1 end),
    getpos = spy.new(function(marker)
      if marker == "'<" then return {0,1,1,0} end
      if marker == "'>" then return {0,1,1,0} end
      return {0,0,0,0}
    end),
    line = spy.new(function() return 1 end),
    col = spy.new(function() return 1 end),
    getline = spy.new(function() return {""} end),
    setline = spy.new(function() end),
    split = spy.new(function(str, sep)
        sep = sep or "\n"; local result = {}; if str == nil then return result end
        if #str == 0 then table.insert(result, ""); return result end
        local current_segment = ""; for i = 1, #str do local char = str:sub(i, i)
        if char == sep then table.insert(result, current_segment); current_segment = ""
        else current_segment = current_segment .. char end end
        table.insert(result, current_segment); return result
    end),
    exists = spy.new(function() return 0 end),
    has = spy.new(function() return 0 end),
    expand = spy.new(function(str) return str end),
    stdpath = spy.new(function(type) return "/tmp/nvim-" .. type end),
    glob = spy.new(function() return {} end),
    fnamemodify = spy.new(function(fname, mods) return fname end),
    isdirectory = spy.new(function(path)
      if mock_rtp_components[path] then
        return 1
      end
      return 0
    end),
    filereadable = spy.new(function(path) return 0 end),
  },
  loop = {
    now = spy.new(function() return 1234567890 end),
    new_timer = spy.new(function() return { start = function() end, stop = function() end, close = function() end, again = function() end } end),
    fs_stat = spy.new(function() return nil end)
  },
  log = {
    levels = { ERROR = 1, WARN = 2, INFO = 3, DEBUG = 4 }
  },
  o = {
    runtimepath = "/tmp/nvim-mock-data/site,/tmp/nvim-mock-data/user-plugin,/tmp/nvim-mock-data/site/after",
    packpath = "/tmp/nvim-mock-data/site,/tmp/nvim-mock-data/user-plugin,/tmp/nvim-mock-data/site/after",
  },
  bo = {},
  wo = {},
  go = {},
  v = {
    errmsg = ""
  },
  uv = {},
  schedule = spy.new(function(fn_to_schedule)
  end),
  deepcopy = spy.new(function(val)
    if type(val) ~= 'table' then return val end
    local res = {}
    for k, v_ in pairs(val) do res[M.mocked_vim.deepcopy(k)] = M.mocked_vim.deepcopy(v_) end
    return res
  end),
  tbl_isempty = function(tbl) return next(tbl) == nil end,
  tbl_deep_extend = spy.new(function() return {} end),
  notify = spy.new(function() end),
  inspect = (original_vim_global and original_vim_global.inspect) or inspect_fallback,
  cmd = spy.new(function(command_string) end),
  print = spy.new(print)
}

local function merge_tables(dst, src)
  for k, v in ipairs(src) do dst[k] = v end
end

function M.setup(custom_mocks)
  local base_vim = original_vim_global or {}
  _G.vim  = setmetatable({}, { __index = base_vim })
  merge_tables(_G.vim, M.mocked_vim)

  _G.vim.fn = M.mocked_vim.fn

  M.mocked_vim.o.runtimepath = M.mocked_vim.o.runtimepath or "/tmp/nvim-mock-data/site"
  M.mocked_vim.o.packpath = M.mocked_vim.o.packpath or "/tmp/nvim-mock-data/site"


  if custom_mocks then
    for main_key, main_value in pairs(custom_mocks) do
      if type(main_value) == 'table' and type(_G.vim[main_key]) == 'table' then
        for sub_key, sub_value in pairs(main_value) do
          if type(sub_value) == 'function' and not sub_value.is_spy then
            _G.vim[main_key][sub_key] = spy.new(sub_value)
          else
            _G.vim[main_key][sub_key] = sub_value
          end
        end
      else
        if type(main_value) == 'function' then
          _G.vim[main_key] = spy.new(main_value)
        else
          _G.vim[main_key] = main_value
        end
      end
    end
  end
end

function M.teardown()
  _G.vim = original_vim_global
  _G.pcall = original_pcall_global
end

return M
