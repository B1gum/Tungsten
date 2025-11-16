local M = {}

local numpy_special_function_whitelist = {
	erf = true,
	erfc = true,
	sinc = true,
}

local special_function_names = {}
local known_special_functions = {
	"airy_ai",
	"airy_bi",
	"assoc_legendre",
	"besselj",
	"besseli",
	"besselk",
	"bessely",
	"chebyshevt",
	"chebyshevu",
	"dirichlet_eta",
	"ellipticf",
	"elliptice",
	"ellipticpi",
	"fresnelc",
	"fresnels",
	"gegenbauer",
	"gamma",
	"gammainc",
	"gammaincc",
	"hermite",
	"hyper",
	"hyperu",
	"jacobi",
	"laguerre",
	"lambertw",
	"legendre",
	"loggamma",
	"meijerg",
	"polygamma",
	"struveh",
	"struvel",
	"whittakerm",
	"whittakerw",
	"zeta",
}

for _, name in ipairs(known_special_functions) do
	special_function_names[name] = true
end
for name in pairs(numpy_special_function_whitelist) do
	special_function_names[name] = true
end

local function normalize_name(name)
	if type(name) ~= "string" then
		return nil
	end
	return name:lower()
end

local function extract_function_name(node)
	if type(node) ~= "table" then
		return nil
	end
	if node.name then
		return node.name
	end
	if node.name_node and node.name_node.name then
		return node.name_node.name
	end
	return nil
end

local function is_numpy_supported_special_function(name)
	local normalized = normalize_name(name)
	if not normalized then
		return true
	end
	if not special_function_names[normalized] then
		return true
	end
	return numpy_special_function_whitelist[normalized] or false
end

local function walk(node, seen)
	if type(node) ~= "table" or seen[node] then
		return nil
	end
	seen[node] = true

	if node.type == "function_call" then
		local func_name = extract_function_name(node.name_node) or node.name
		local normalized = normalize_name(func_name)
		if not normalized and type(node.name_node) == "table" then
			normalized = normalize_name(node.name_node.name)
		end
		if normalized and special_function_names[normalized] and not numpy_special_function_whitelist[normalized] then
			return func_name or normalized
		end
	end

	for _, child in pairs(node) do
		local offending = walk(child, seen)
		if offending then
			return offending
		end
	end

	return nil
end

function M.find_disallowed_special_function(ast)
	return walk(ast, {})
end

function M.is_special_function(name)
	local normalized = normalize_name(name)
	if not normalized then
		return false
	end
	return special_function_names[normalized] or false
end

function M.is_numpy_supported(name)
	return is_numpy_supported_special_function(name)
end

M.numpy_special_function_whitelist = numpy_special_function_whitelist

return M
