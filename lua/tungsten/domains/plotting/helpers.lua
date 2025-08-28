local M = {}

local function collect_names(node, acc)
        if type(node) ~= "table" then
                return
        end
        local t = node.type
        if t == "function_call" then
                for _, arg in ipairs(node.args or {}) do
                        collect_names(arg, acc)
                end
                return
        end
        if t == "variable" or t == "symbol" or t == "greek" then
                acc[node.name] = true
        end
        for k, v in pairs(node) do
                if k ~= "type" and type(v) == "table" then
                        if v.type then
                                collect_names(v, acc)
                        else
                                for _, child in pairs(v) do
                                        collect_names(child, acc)
                                end
                        end
                end
        end
end

function M.extract_param_names(expr)
        local set = {}
        collect_names(expr, set)
        local result = {}
        for name in pairs(set) do
                table.insert(result, name)
        end
        table.sort(result)
        return result
end

function M.detect_point2_param(point)
        if not point or point.type ~= "Point2" then
                return nil
        end
        local x_params = M.extract_param_names(point.x)
        local y_params = M.extract_param_names(point.y)
        if #x_params == 1 and #y_params == 1 and x_params[1] == y_params[1] then
                return x_params[1]
        end
        return nil
end

function M.is_theta_function(expr)
        local params = M.extract_param_names(expr)
        return #params == 1 and params[1] == "theta"
end

return M
