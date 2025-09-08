-- tests/helpers/mock_utils.lua
local spy = require("luassert.spy")

local original_on = spy.on
spy.on = function(tbl, key, ...)
	local s = original_on(tbl, key, ...)
	if type(s) == "table" and s.call_fake == nil then
		function s:call_fake(fn)
			tbl[key] = spy.new(fn)
			return tbl[key]
		end
	end
	return s
end

local stub = require("luassert.stub")

local M = {}

function M.mock_module(module_name, mock_table)
	mock_table = mock_table or {}
	for key, value in pairs(mock_table) do
		if type(value) == "function" then
			mock_table[key] = stub.new(mock_table, key, value)
		end
	end
	package.loaded[module_name] = mock_table
	return mock_table
end

function M.reset_modules(module_names)
	for _, name in ipairs(module_names) do
		package.loaded[name] = nil
	end
end

function M.create_empty_mock_module(module_name, function_names)
	local mock = {}
	if function_names then
		for _, fn_name in ipairs(function_names) do
			local st = stub.new(mock, fn_name)
			if type(st.calls) ~= "function" then
				st.calls = function(self, fn)
					self.invokes = fn
				end
			end
			mock[fn_name] = st
		end
	end
	package.loaded[module_name] = mock
	return mock
end

function M.mock_table(methods_to_mock)
	local tbl = {}
	if methods_to_mock then
		for _, method_name in ipairs(methods_to_mock) do
			tbl[method_name] = stub.new(tbl, method_name)
		end
	end
	return tbl
end

return M
