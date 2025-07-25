-- tests/unit/core/render_spec.lua
-- Unit tests for the AST rendering logic in lua/tungsten/core/render.lua

local match = require("luassert.match")

local spy = require("luassert.spy")
local render_module = require("tungsten.core.render")

describe("tungsten.core.render", function()
	local render = render_module.render
	local mock_handlers

	before_each(function()
		mock_handlers = {
			node_type_A = spy.new(function(node, walk)
				if node.child then
					local res = walk(node.child)
					if type(res) == "table" and res.error then
						return res
					end
					return "rendered_A(" .. res .. ")"
				elseif node.children then
					local rendered_children = {}
					for _, child_node in ipairs(node.children) do
						local res_child = walk(child_node)
						if type(res_child) == "table" and res_child.error then
							return res_child
						end
						table.insert(rendered_children, res_child)
					end
					return "rendered_A_multiple(" .. table.concat(rendered_children, ", ") .. ")"
				else
					return "rendered_A_no_children"
				end
			end),
			node_type_B = spy.new(function(node, _)
				return "leaf_B:" .. node.value
			end),
			node_type_C = spy.new(function(node, walk)
				local res = walk(node.data)
				if type(res) == "table" and res.error then
					return res
				end
				return "rendered_C{" .. res .. "}"
			end),
			erroring_node = spy.new(function(node, walk)
				error("Error inside erroring_node handler!")
			end),
			node_returns_error_obj = spy.new(function(node, walk)
				local child_result = walk(node.child_that_will_error)
				if type(child_result) == "table" and child_result.error then
					return child_result
				end
				return "should_not_reach_here"
			end),
			leaf_node = spy.new(function(node, walk)
				return "leaf_value:" .. tostring(node.value)
			end),
		}
	end)

	it("should correctly call the handler for a given node type and return its result", function()
		local ast = { type = "node_type_B", value = "test_value" }
		local result = render(ast, mock_handlers)
		assert.spy(mock_handlers.node_type_B).was.called_with(ast, match.is_function())
		assert.are.equal("leaf_B:test_value", result)
	end)

	it("should pass the node and the recursive walk function to the handler", function()
		local ast = { type = "node_type_A" }
		render(ast, mock_handlers)
		assert.spy(mock_handlers.node_type_A).was.called(1)
		local call_args = mock_handlers.node_type_A.calls[1].vals
		assert.are.same(ast, call_args[1])
		assert.is_function(call_args[2], "Second argument to handler was not a function")
	end)

	it("should correctly render a simple nested AST structure", function()
		local ast = {
			type = "node_type_A",
			child = { type = "node_type_B", value = "child_value" },
		}
		local result = render(ast, mock_handlers)
		assert.spy(mock_handlers.node_type_A).was.called(1)
		assert.spy(mock_handlers.node_type_B).was.called(1)
		assert.spy(mock_handlers.node_type_B).was.called_with(ast.child, match.is_function())
		assert.are.equal("rendered_A(leaf_B:child_value)", result)
	end)

	it("the walk function passed to handlers correctly invokes _walk for child nodes", function()
		local inner_child_node = { type = "node_type_B", value = "inner_child" }
		local child_node = { type = "node_type_C", data = inner_child_node }
		local root_ast = { type = "node_type_A", child = child_node }

		render(root_ast, mock_handlers)

		assert.spy(mock_handlers.node_type_A).was.called_with(root_ast, match.is_function())
		assert.spy(mock_handlers.node_type_C).was.called_with(child_node, match.is_function())
		assert.spy(mock_handlers.node_type_B).was.called_with(inner_child_node, match.is_function())
	end)

	it("should correctly render a deeply nested AST structure", function()
		local ast = {
			type = "node_type_A",
			child = {
				type = "node_type_C",
				data = {
					type = "node_type_A",
					child = { type = "node_type_B", value = "deep_value" },
				},
			},
		}
		local result = render(ast, mock_handlers)
		assert.are.equal("rendered_A(rendered_C{rendered_A(leaf_B:deep_value)})", result)
	end)

	it("should correctly render an AST with multiple children at the same level", function()
		local ast = {
			type = "node_type_A",
			children = {
				{ type = "node_type_B", value = "child1" },
				{ type = "node_type_C", data = { type = "node_type_B", value = "child2_data" } },
				{ type = "node_type_B", value = "child3" },
			},
		}
		local result = render(ast, mock_handlers)
		assert.are.equal("rendered_A_multiple(leaf_B:child1, rendered_C{leaf_B:child2_data}, leaf_B:child3)", result)
	end)

	it("should convert non-table nodes (primitives) to string", function()
		local ast_string_node = "this_is_a_string_node"
		local ast_number_node = 12345
		local ast_boolean_node = true

		assert.are.equal("this_is_a_string_node", render(ast_string_node, mock_handlers))
		assert.are.equal("12345", render(ast_number_node, mock_handlers))
		assert.are.equal("true", render(ast_boolean_node, mock_handlers))
	end)

	describe("Error Propagation and Handling", function()
		it("should throw an error if handlers argument is not a table", function()
			local ast = { type = "node_type_A" }
			assert.has_error(function()
				render(ast, nil)
			end, "render.render: handlers must be a table")
			assert.has_error(function()
				render(ast, "not_a_table")
			end, "render.render: handlers must be a table")
		end)

		it("should throw an error if a table node lacks a 'type' field (direct error)", function()
			local ast_no_type = { value = "something" }
			assert.has_error(function()
				render(ast_no_type, mock_handlers)
			end, "render.walk: node missing tag/type field")
		end)

		it("should throw an error if node.type is nil (direct error)", function()
			local ast = { type = nil, data = "some data" }
			assert.has_error(function()
				render(ast, mock_handlers)
			end, "render.walk: node missing tag/type field")
		end)

		it("should return an error table if no handler is found for a given node type", function()
			local ast_unknown_type = { type = "unknown_node_type", value = "mystery" }
			local result = render(ast_unknown_type, mock_handlers)
			assert.is_table(result)
			assert.is_true(result.error)
			assert.are.equal('render.walk: no handler for tag "unknown_node_type"', result.message)
			assert.are.equal("unknown_node_type", result.node_type)
		end)

		it("should return an error table if handler for a node type is nil", function()
			local ast = { type = "node_type_nil_handler" }
			local handlers_with_nil = {
				node_type_nil_handler = nil,
			}
			local result = render(ast, handlers_with_nil)
			assert.is_table(result)
			assert.is_true(result.error)
			assert.are.equal('render.walk: no handler for tag "node_type_nil_handler"', result.message)
		end)

		it("should return an error table if a handler function itself throws an error", function()
			local ast = { type = "erroring_node" }
			local result = render(ast, mock_handlers)
			assert.is_table(result)
			assert.is_true(result.error)
			assert.truthy(string.find(result.message, "Error in handler for tag 'erroring_node'"))
			assert.truthy(string.find(result.message, "Error inside erroring_node handler!"))
			assert.are.equal("erroring_node", result.node_type)
		end)

		it("should propagate an error table returned by a child's _walk call (e.g. missing handler for child)", function()
			local ast = {
				type = "node_type_A",
				child = { type = "unknown_type_child" },
			}
			local result = render(ast, mock_handlers)
			assert.is_table(result)
			assert.is_true(result.error, "Expected top-level result to be an error table")
			assert.are.equal('render.walk: no handler for tag "unknown_type_child"', result.message)
			assert.are.equal("unknown_type_child", result.node_type)
		end)

		it("should propagate an error table if a handler for a child node errors", function()
			local ast = {
				type = "node_type_A",
				child = { type = "erroring_node" },
			}
			local result = render(ast, mock_handlers)
			assert.is_table(result)
			assert.is_true(result.error)
			assert.truthy(string.find(result.message, "Error in handler for tag 'erroring_node'"))
			assert.truthy(string.find(result.message, "Error inside erroring_node handler!"))
			assert.are.equal("erroring_node", result.node_type)
		end)

		it("should propagate error from a deeply nested handler that errors", function()
			mock_handlers.level1 = spy.new(function(node, walk)
				local res = walk(node.child)
				if type(res) == "table" and res.error then
					return res
				end
				return "L1(" .. res .. ")"
			end)
			mock_handlers.level2 = spy.new(function(node, walk)
				local res = walk(node.child)
				if type(res) == "table" and res.error then
					return res
				end
				return "L2(" .. res .. ")"
			end)

			local ast = {
				type = "level1",
				child = {
					type = "level2",
					child = { type = "erroring_node" },
				},
			}
			local result = render(ast, mock_handlers)
			assert.is_table(result)
			assert.is_true(result.error)
			assert.truthy(string.find(result.message, "Error in handler for tag 'erroring_node'"))
			assert.are.equal("erroring_node", result.node_type)
		end)

		it(
			"should correctly use the walk function that checks for errors when calling child nodes (handler returns error obj)",
			function()
				local ast = {
					type = "node_returns_error_obj",
					child_that_will_error = { type = "unknown_child" },
				}
				local result = render(ast, mock_handlers)
				assert.is_table(result)
				assert.is_true(result.error)
				assert.are.equal('render.walk: no handler for tag "unknown_child"', result.message)
				assert.are.equal("unknown_child", result.node_type)
			end
		)
	end)

	it("should handle ASTs with mixed primitive and table children if handler supports it (via walk)", function()
		mock_handlers.node_type_mixed = spy.new(function(node, walk)
			local parts = {}
			for _, item in ipairs(node.items) do
				table.insert(parts, walk(item))
			end
			return "mixed(" .. table.concat(parts, ";") .. ")"
		end)

		local ast = {
			type = "node_type_mixed",
			items = {
				{ type = "node_type_B", value = "item1" },
				"primitive_string",
				{ type = "node_type_A" },
				123,
			},
		}
		local result = render(ast, mock_handlers)
		assert.are.equal("mixed(leaf_B:item1;primitive_string;rendered_A_no_children;123)", result)
	end)

	it("should correctly pass the walk function, which should itself be callable and work recursively", function()
		local handlers_for_walk_test = {
			outer = spy.new(function(node, walk)
				return "OuterStart:" .. walk(node.child1) .. ":" .. walk(node.child2) .. ":OuterEnd"
			end),
			middle = spy.new(function(node, walk)
				return "Middle(" .. walk(node.data) .. ")"
			end),
			leaf = spy.new(function(node, _)
				return "Leaf(" .. node.val .. ")"
			end),
		}

		local ast = {
			type = "outer",
			child1 = { type = "middle", data = { type = "leaf", val = "L1" } },
			child2 = { type = "leaf", val = "L2" },
		}

		local result = render(ast, handlers_for_walk_test)

		assert.spy(handlers_for_walk_test.outer).was.called(1)
		assert.spy(handlers_for_walk_test.middle).was.called(1)
		assert.spy(handlers_for_walk_test.leaf).was.called(2)

		local outer_call = handlers_for_walk_test.outer.calls[1]
		local middle_call = handlers_for_walk_test.middle.calls[1]
		local leaf_call1 = handlers_for_walk_test.leaf.calls[1]
		local leaf_call2 = handlers_for_walk_test.leaf.calls[2]

		assert.are.same(ast, outer_call.vals[1])
		assert.is_function(outer_call.vals[2])

		assert.are.same(ast.child1, middle_call.vals[1])
		assert.is_function(middle_call.vals[2])

		assert.are.same(ast.child1.data, leaf_call1.vals[1])
		assert.is_function(leaf_call1.vals[2])
		assert.are.same(ast.child2, leaf_call2.vals[1])
		assert.is_function(leaf_call2.vals[2])

		assert.are.equal("OuterStart:Middle(Leaf(L1)):Leaf(L2):OuterEnd", result)
	end)
end)
