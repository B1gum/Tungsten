-- tests/unit/core/parser_error_spec.lua
-- Unit tests for parser error reporting using lpeglabel

package.loaded["tungsten.core.registry"] = nil
package.loaded["tungsten.core.parser"] = nil
package.loaded["tungsten.core"] = nil
package.loaded["tungsten.domains.arithmetic"] = nil
package.loaded["tungsten.domains.calculus"] = nil
package.loaded["tungsten.domains.linear_algebra"] = nil
package.loaded["tungsten.domains.differential_equations"] = nil

local parser = require("tungsten.core.parser")
local error_handler = require("tungsten.util.error_handler")
require("tungsten.core")

describe("tungsten.core.parser.parse error reporting", function()
	it("returns label, position, and formatted location for malformed input", function()
		local ast, err, pos, input = parser.parse("1 +")
		assert.is_nil(ast)
		assert.is_truthy(err:match("syntax error") or err:match("unexpected"))
		assert.is_number(pos)
		assert.are.equal("line 1, column " .. tostring(pos), error_handler.format_line_col(input, pos))
	end)

	it("returns a specific error for chained inequalities", function()
		local ast, err = parser.parse("a < b < c")
		assert.is_nil(ast)
		assert.matches("Chained inequalities are not supported %(v1%).", err)
	end)
end)
