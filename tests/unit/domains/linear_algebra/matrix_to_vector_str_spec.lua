-- tests/unit/domains/linear_algebra/matrix_to_vector_str_spec.lua
-- Unit tests for the matrix_to_vector_str helper.

local spy = require 'luassert.spy'
local wolfram_handlers = require 'tungsten.domains.linear_algebra.wolfram_handlers'

local matrix_to_vector_str = wolfram_handlers.matrix_to_vector_str

local function ast_node(type, props)
  props = props or {}
  props.type = type
  return props
end

describe('matrix_to_vector_str', function()
  local mock_render

  before_each(function()
    mock_render = spy.new(function(node)
      if node.type == 'number' then return tostring(node.value) end
      if node.type == 'variable' then return node.name end
      if node.type == 'matrix' then return 'rendered_matrix' end
      return 'unknown'
    end)
  end)

  it('converts a 3x1 numeric matrix to a vector string', function()
    local node = ast_node('matrix', {
      rows = {
        { ast_node('number', { value = 1 }) },
        { ast_node('number', { value = 2 }) },
        { ast_node('number', { value = 3 }) },
      }
    })
    local res = matrix_to_vector_str(node, mock_render)
    assert.are.equal('{1, 2, 3}', res)
  end)

  it('handles matrices with symbolic entries', function()
    local node = ast_node('matrix', {
      rows = {
        { ast_node('variable', { name = 'x' }), ast_node('variable', { name = 'y' }) }
      }
    })
    local res = matrix_to_vector_str(node, mock_render)
    assert.are.equal('{x, y}', res)
  end)

  it('returns {} for an empty matrix', function()
    local node = ast_node('matrix', { rows = {} })
    local res = matrix_to_vector_str(node, mock_render)
    assert.are.equal('{}', res)
  end)

  it('delegates to render for irregular matrices', function()
    local node = ast_node('matrix', {
      rows = {
        { ast_node('number', { value = 1 }), ast_node('number', { value = 2 }) },
        { ast_node('number', { value = 3 }), ast_node('number', { value = 4 }) },
      }
    })
    local res = matrix_to_vector_str(node, mock_render)
    assert.are.equal('rendered_matrix', res)
    assert.spy(mock_render).was.called_with(node)
  end)
end)

