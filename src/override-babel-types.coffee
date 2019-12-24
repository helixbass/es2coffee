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
