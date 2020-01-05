exports.override = ->
  require '@babel/types'
  {
    default: defineType
    assertNodeType
    assertValueType
    chain
    assertEach
    assertOneOf
    validateOptional
  } = require '@babel/types/lib/definitions/utils'
  # {UNARY_OPERATORS} = require '@babel/types/lib/constants'

  # ### Monkeypatch ###

  # constants.UNARY_OPERATORS = [...constants.UNARY_OPERATORS, '?']

  ### Override ###

  defineType 'ExportNamedDeclaration',
    visitor: ['declaration', 'specifiers', 'source']
    aliases: [
      'Statement'
      'Declaration'
      'ModuleDeclaration'
      'ExportDeclaration'
    ]
    fields:
      declaration:
        validate: assertNodeType 'Declaration', 'AssignmentExpression'
        optional: yes
      specifiers:
        validate: chain(
          assertValueType 'array'
          assertEach(
            assertNodeType(
              'ExportSpecifier'
              'ExportDefaultSpecifier'
              'ExportNamespaceSpecifier'
            )
          )
        )
      source:
        validate: assertNodeType 'StringLiteral'
        optional: yes
      exportKind: validateOptional assertOneOf 'type', 'value'

  defineType 'UnaryExpression',
    visitor: ['argument']
    builder: ['operator', 'argument', 'prefix']
    fields:
      prefix:
        default: yes
      argument:
        validate: assertNodeType 'Expression'
      operator: {}
      # validate: assertOneOf [...UNARY_OPERATORS, '?']

  defineType 'For', visitor: ['name', 'index', 'guard', 'step', 'body']
