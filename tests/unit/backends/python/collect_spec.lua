local python = os.getenv("TUNGSTEN_TEST_PYTHON")
if not python then
	local venv = vim.fn.getcwd() .. "/.venv"
	if vim.fn.executable(venv .. "/bin/python") == 1 then
		python = venv .. "/bin/python"
	elseif vim.fn.executable(venv .. "/Scripts/python.exe") == 1 then
		python = venv .. "/Scripts/python.exe"
	else
		python = "python3"
	end
end
local has_sympy = false
if vim.fn.executable(python) == 1 then
	vim.fn.system({ python, "-c", "import sympy" })
	has_sympy = vim.v.shell_error == 0
end

local function variable(name)
	return { type = "variable", name = name }
end

local function number(value)
	return { type = "number", value = value }
end

local function binary(operator, left, right)
	return { type = "binary", operator = operator, left = left, right = right }
end

local function collect(expression, target)
	return {
		type = "function_call",
		name_node = variable("Collect"),
		args = { expression, target, variable("Simplify") },
	}
end

local function clear_tungsten_modules()
	for name in pairs(package.loaded) do
		if name:match("^tungsten%.") then
			package.loaded[name] = nil
		end
	end
end

describe("Python Collect backend", function()
	local saved_modules
	local config
	local executor
	local handlers
	local renderer

	before_each(function()
		saved_modules = {}
		for name, module in pairs(package.loaded) do
			if name:match("^tungsten%.") then
				saved_modules[name] = module
			end
		end
		clear_tungsten_modules()
		config = require("tungsten.config")
		executor = require("tungsten.backends.python.executor")
		handlers = require("tungsten.backends.python.domains.arithmetic").handlers
		renderer = require("tungsten.core.render")
	end)

	after_each(function()
		clear_tungsten_modules()
		for name, module in pairs(saved_modules) do
			package.loaded[name] = module
		end
	end)

	local function render(node)
		local code = renderer.render(node, handlers)
		assert.are.equal("string", type(code))
		return code
	end

	local function build(node, numeric)
		return executor.build_command(render(node), { ast = node, numeric = numeric })
	end

	it("expands the input and passes a callable coefficient simplifier", function()
		assert.are.equal(
			"_apply(sp.collect, sp.expand(expr), x, sp.simplify)",
			render(collect(variable("expr"), variable("x")))
		)
	end)

	it("renders subscripted collection targets consistently", function()
		local target = { type = "subscript", base = variable("C"), subscript = variable("l") }
		assert.are.equal(
			"_apply(sp.collect, sp.expand(Symbol('C_l')), Symbol('C_l'), sp.simplify)",
			render(collect(target, target))
		)
	end)

	it("does not declare the Collect wrapper or its callback as user symbols", function()
		local command = build(collect(variable("expr"), variable("x")))[2]
		assert.is_nil(command:find("Collect = ", 1, true))
		assert.is_nil(command:find("Simplify = ", 1, true))
		assert.is_true(command:find("x = sp.Symbol('x')", 1, true) ~= nil)
	end)

	it("preserves a mathematical symbol named Simplify in the expression", function()
		local node = collect(binary("*", variable("Simplify"), variable("x")), variable("x"))
		local command = build(node)[2]
		assert.is_true(command:find("Simplify = sp.Symbol('Simplify')", 1, true) ~= nil)
		assert.is_true(command:find("sp.expand(Simplify * x), x, sp.simplify", 1, true) ~= nil)
	end)

	it("honours a custom Python Collect mapping", function()
		config.backend_opts.python = { function_mappings = { collect = "custom_collect" } }
		assert.are.equal(
			"_apply(custom_collect, sp.expand(expr), x, sp.simplify)",
			render(collect(variable("expr"), variable("x")))
		)
	end)

	it("uses the existing numeric evaluation pipeline", function()
		local command = build(collect(variable("expr"), variable("x")), true)[2]
		assert.is_true(command:find("expr = sp.N(_apply(sp.collect,", 1, true) ~= nil)
	end)

	describe("SymPy execution", function()
		local execution_test = has_sympy and it or pending

		local function execute(node, checks, numeric)
			local args = build(node, numeric)
			local output = vim.fn.system({ python, args[1], args[2] .. "; " .. checks })
			assert.are.equal(0, vim.v.shell_error, output)
			return output
		end

		local function unexpanded_polynomial(target)
			return binary(
				"+",
				binary("*", target, binary("+", target, number(1))),
				binary("*", target, binary("+", binary("^", target, number(2)), binary("*", number(3), target)))
			)
		end

		execution_test("expands the documented input and produces the expected polynomial", function()
			local x = variable("x")
			execute(collect(unexpanded_polynomial(x), x), "assert expr == x**3 + 4*x**2 + x")
		end)

		execution_test("groups symbolic coefficients by the selected variable", function()
			local x = variable("x")
			local quadratic = binary(
				"+",
				binary("*", variable("a"), binary("^", x, number(2))),
				binary("*", variable("b"), binary("^", x, number(2)))
			)
			local expression =
				binary("+", quadratic, binary("+", binary("*", variable("c"), x), binary("*", variable("d"), x)))
			execute(collect(expression, x), "assert expr.coeff(x, 2) == a + b; assert expr.coeff(x, 1) == c + d")
		end)

		execution_test("simplifies each symbolic coefficient", function()
			local a = variable("a")
			local x = variable("x")
			local coefficient = {
				type = "fraction",
				numerator = binary("-", binary("^", a, number(2)), number(1)),
				denominator = binary("-", a, number(1)),
			}
			execute(collect(binary("*", coefficient, x), x), "assert expr.coeff(x) == a + 1")
		end)

		execution_test("collects by a subscripted symbol", function()
			local target = { type = "subscript", base = variable("C"), subscript = variable("l") }
			execute(
				collect(unexpanded_polynomial(target), target),
				"target = sp.Symbol('C_l'); assert expr == target**3 + 4*target**2 + target"
			)
		end)

		execution_test("returns approximate coefficients in numeric mode", function()
			local x = variable("x")
			local half = { type = "fraction", numerator = number(1), denominator = number(2) }
			execute(
				collect(binary("*", half, x), x),
				"assert expr.coeff(x).is_Float; assert abs(float(expr.coeff(x)) - 0.5) < 1e-12",
				true
			)
		end)

		execution_test("handles zero and constant expressions", function()
			for _, value in ipairs({ 0, 5 }) do
				execute(collect(number(value), variable("x")), ("assert expr == %d"):format(value))
			end
		end)
	end)
end)
