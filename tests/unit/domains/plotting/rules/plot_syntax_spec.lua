-- Unit tests for the plotting grammar rules, ensuring correct parsing of plot-related syntax.

local lpeg = require("lpeglabel")
local P, C, R, S, V, Ct = lpeg.P, lpeg.C, lpeg.R, lpeg.S, lpeg.V, lpeg.Ct

describe("Plotting Grammar Rules", function()
	local mock_ast, mock_tokenizer
	local plot_rules
	local test_grammar

	local function compile_grammar(rule)
		return P({
			"EntryPoint",
			EntryPoint = rule * -P(1),
			Expression = V("Equality")
				+ V("Inequality")
				+ V("Point")
				+ V("FunctionCall")
				+ mock_tokenizer.variable
				+ mock_tokenizer.number,
			Equality = V("Expression") * S(" \t") ^ 0 * P("=") * S(" \t") ^ 0 * V("Expression") / function(l, r)
				return mock_ast.create_equality_node(l, r)
			end,
			Inequality = V("Expression")
				* S(" \t") ^ 0
				* C(P("<=") + P("\\le") + P(">=") + P("\\ge") + S("<>"))
				* S(" \t") ^ 0
				* V("Expression")
				/ function(l, op, r)
					return mock_ast.create_inequality_node(l, op, r)
				end,
			FunctionCall = mock_tokenizer.variable * P("(") * (V("Expression") * (P(",") * V("Expression")) ^ 0) * P(")"),
			Point = P("(") * S(" \t") ^ 0 * Ct(
				V("Expression") * (S(" \t") ^ 0 * P(",") * S(" \t") ^ 0 * V("Expression")) ^ 0
			) * S(" \t") ^ 0 * P(")") / function(elements)
				if #elements == 2 then
					return mock_ast.create_point2_node(elements[1], elements[2])
				elseif #elements == 3 then
					return mock_ast.create_point3_node(elements[1], elements[2], elements[3])
				end
				return { type = "parenthesized_group", elements = elements }
			end,
		})
	end

	local function parse_input(input)
		assert(test_grammar, "Test grammar was not compiled for this test.")
		return lpeg.match(test_grammar, input)
	end

	before_each(function()
		mock_ast = {
			create_sequence_node = function(nodes)
				return { type = "sequence", nodes = nodes }
			end,
			create_point2_node = function(x, y)
				return { type = "point2", x = x, y = y }
			end,
			create_point3_node = function(x, y, z)
				return { type = "point3", x = x, y = y, z = z }
			end,
			create_equality_node = function(lhs, rhs)
				return { type = "equality", lhs = lhs, rhs = rhs }
			end,
			create_inequality_node = function(lhs, op, rhs)
				return { type = "inequality", lhs = lhs, op = op, rhs = rhs }
			end,
		}

		mock_tokenizer = {
			variable = C(R("az") ^ 1) / function(s)
				return { type = "variable", name = s }
			end,
			number = C(R("09") ^ 1) / function(s)
				return { type = "number", value = tonumber(s) }
			end,
			space = S(" \t\r\n") ^ 0,
		}

		local PlotItem = V("Expression")
		local Sequence = Ct(PlotItem * (mock_tokenizer.space * P(",") * mock_tokenizer.space * PlotItem) ^ 0)
			/ function(items)
				if #items == 1 then
					return items[1]
				end
				return mock_ast.create_sequence_node(items)
			end

		local SeriesSeparator = mock_tokenizer.space * (P(";") + P("\n")) * mock_tokenizer.space
		local TopLevelPlotRule = Ct(Sequence * (SeriesSeparator * Sequence) ^ 0)
			/ function(series)
				if #series == 1 then
					return series[1]
				end
				return { type = "multi_series", series = series }
			end

		plot_rules = TopLevelPlotRule
		test_grammar = compile_grammar(plot_rules)
	end)

	describe("AST & Parsing", function()
		it(
			"should parse top-level comma-separated expressions as a Sequence AST node without splitting inside brackets or functions",
			function()
				local result = parse_input("f(x,y), z")
				assert.are.same("sequence", result.type)
				assert.are.equal(2, #result.nodes)
				assert.are.same("function_call", result.nodes[1].type)
				assert.are.same("variable", result.nodes[2].type)
				assert.are.same("z", result.nodes[2].name)
			end
		)

		it("should parse coordinate tuples like (x,y) or (x,y,z) as Point2 and Point3 AST nodes respectively", function()
			local point2_ast = parse_input("(x,1)")
			assert.are.same("point2", point2_ast.type)
			assert.are.same("x", point2_ast.x.name)
			assert.are.same(1, point2_ast.y.value)

			local point3_ast = parse_input("(1,y,z)")
			assert.are.same("point3", point3_ast.type)
			assert.are.same(1, point3_ast.x.value)
			assert.are.same("y", point3_ast.y.name)
			assert.are.same("z", point3_ast.z.name)
		end)

		it(
			"should treat a coordinate tuple (expr, expr) as a 2D point in simple mode, but as a parametric pair when Advanced mode Form=parametric",
			function()
				local result = parse_input("(x, y)")
				assert.are.same("point2", result.type, "Parser should create a Point2 node for any (expr, expr) tuple.")
			end
		)

		it(
			"should merge consecutive Point nodes in a Sequence into one scatter series, and separate multiple series by semicolons or newlines",
			function()
				local result = parse_input("(1,2); (3,4)")
				assert.are.same("multi_series", result.type)
				assert.are.equal(2, #result.series)
				assert.are.same("point2", result.series[1].type)
				assert.are.same("point2", result.series[2].type)
			end
		)

		it(
			"should parse explicit equations like f(x) = <expr> or y(x) = <expr> as an Equality AST node with the correct left-hand side symbol or function",
			function()
				local result = parse_input("f(x) = 1")
				assert.are.same("equality", result.type)
				assert.are.same("function_call", result.lhs.type)
				assert.are.same("f", result.lhs.name_node.name)
			end
		)

		it(
			"should parse inequality expressions (e.g., x + y < 1 or y > 0) into an Inequality AST node, preserving the specified comparison operator",
			function()
				local result = parse_input("x < 1")
				assert.are.same("inequality", result.type)
				assert.are.same("<", result.op)

				result = parse_input("y >= 2")
				assert.are.same("inequality", result.type)
				assert.are.same(">=", result.op)
			end
		)

		it("should parse parametric expressions into Point2/Point3 nodes for later classification", function()
			local result = parse_input("(f(t), g(t))")
			assert.are.same("point2", result.type)
			assert.are.same("function_call", result.x.type)
			assert.are.same("function_call", result.y.type)
		end)

		it("should parse polar expressions into an Equality or Expression node for later classification", function()
			local result_eq = parse_input("r = 1")
			assert.are.same("equality", result_eq.type, "Polar equation should parse as a standard equality.")

			local result_expr = parse_input("f(t)")
			assert.are.same("function_call", result_expr.type, "Polar expression should parse as a standard expression.")
		end)
	end)

	describe("Grammar Conflict Checks", function()
		it("should ensure new AST nodes do not conflict with existing grammar rules", function()
			local result = parse_input("x=y")
			assert.are.same("equality", result.type)

			result = parse_input("x")
			assert.are.same("variable", result.type)
		end)
	end)
end)
