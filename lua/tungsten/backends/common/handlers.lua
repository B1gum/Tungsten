local M = {}

M.handlers = {
        number = function(node)
                return tostring(node.value)
        end,
        variable = function(node)
                return node.name
        end,
        greek = function(node)
                return node.name
        end,
}

return M.handlers
