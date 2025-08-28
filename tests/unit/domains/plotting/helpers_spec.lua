describe("Plotting helper utilities", function()
        local ast = require("tungsten.core.ast")
        local helpers = require("tungsten.domains.plotting.helpers")

        local function var(name)
                return ast.create_variable_node(name)
        end

        it("detects single-parameter Point2", function()
                local point = ast.create_point2_node(
                        ast.create_function_call_node(var("cos"), { var("t") }),
                        ast.create_function_call_node(var("sin"), { var("t") })
                )
                assert.are.equal("t", helpers.detect_point2_param(point))
        end)

        it("extracts candidate parameter names", function()
                local expr = ast.create_binary_operation_node(
                        "+",
                        ast.create_superscript_node(var("u"), ast.create_number_node(2)),
                        ast.create_superscript_node(var("v"), ast.create_number_node(2))
                )
                local params = helpers.extract_param_names(expr)
                assert.are.same({ "u", "v" }, params)
        end)

        it("detects f(theta) forms", function()
                local theta_call = ast.create_function_call_node(var("f"), { ast.create_greek_node("theta") })
                assert.is_true(helpers.is_theta_function(theta_call))

                local t_call = ast.create_function_call_node(var("f"), { var("t") })
                assert.is_false(helpers.is_theta_function(t_call))
        end)
end)
