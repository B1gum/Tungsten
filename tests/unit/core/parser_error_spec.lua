-- tests/unit/core/parser_error_spec.lua
-- Unit tests for parser error reporting using lpeglabel

package.loaded["tungsten.core.registry"] = nil
package.loaded["tungsten.core.parser"] = nil
package.loaded["tungsten.core"] = nil
package.loaded["tungsten.domains.arithmetic"] = nil
package.loaded["tungsten.domains.calculus"] = nil
package.loaded["tungsten.domains.linear_algebra"] = nil
package.loaded["tungsten.domains.differential_equations"] = nil

local parser = require "tungsten.core.parser"
require "tungsten.core"

describe("tungsten.core.parser.parse error reporting", function()
  it("returns label and position for malformed input", function()
    local ast, err, pos = parser.parse("1 +")
    assert.is_nil(ast)
    assert.are.equal("fail", err)
    assert.is_number(pos)
  end)
end)

