local M = {}

local subscribers = {}

function M.subscribe(event, handler)
	if type(handler) ~= "function" then
		return
	end
	if not subscribers[event] then
		subscribers[event] = {}
	end
	table.insert(subscribers[event], handler)
end

function M.emit(event, data)
	local handlers = subscribers[event]
	if not handlers then
		return
	end
	for _, fn in ipairs(handlers) do
		pcall(fn, data)
	end
end

return M
