babylon = require 'babylon'
babel = require '@babel/core'
prettier = require 'prettier'
{mapValues: fmapValues} = require 'lodash/fp'

withNullReturnValues = fmapValues (f) ->
  if f.enter or f.exit
    enter: (...args) ->
      f.enter? ...args
      null
    exit: (...args) ->
      f.exit? ...args
      null
  else
    (...args) ->
      f ...args
      null

transformer = ({types: t}) ->
  isSameIdentifier = (a, b) ->
    t.isIdentifier(a) and t.isIdentifier(b) and a.name is b.name

  isSameMemberExpression = (first, second) ->
    a = first
    b = second
    loop
      return yes if isSameIdentifier a, b
      return no unless t.isMemberExpression(a) and t.isMemberExpression(b) and isSameIdentifier(a.property, b.property) and a.computed is b.computed
      a = a.object
      b = b.object

  couldBeIn = ({operator, left, right}) ->
    return no unless operator is 'or'
    return no unless t.isBinaryExpression(left, operator: '===') and t.isBinaryExpression right, operator: '==='
    # return no unless t.isStringLiteral(left.right) and t.isStringLiteral right.right
    return no unless isSameMemberExpression left.left, right.left
    yes

  couldBeMergedIn = ({operator, left, right}) ->
    return no unless operator is 'or'
    t.isBinaryExpression(left, operator: 'in') and t.isArrayExpression(left.right) and t.isBinaryExpression(right, operator: 'is') and isSameMemberExpression left.left, right.left

  findFirstIdentifierUseInMemberExpression =
    Identifier: (path) ->
      {node: {name}, node, parent, key} = path
      return unless name is @name and t.isMemberExpression(parent) and key is 'object'
      @found.push parent
      path.stop()
  findFirstMemberExpressionUseInMemberExpression =
    MemberExpression: (path) ->
      {node: {object, property}, node, parent, key} = path
      return unless t.isIdentifier(object) and object.name is @memberExpr.object.name and t.isIdentifier(property) and property.name is @memberExpr.property.name and t.isMemberExpression(parent) and key is 'object'
      @found.push parent
      path.stop()
  guardingAnd = (path) ->
    {node: {operator, left, right}} = path
    return no unless operator is 'and' and t.isIdentifier(left) or t.isMemberExpression(left) and t.isIdentifier(left.object) and t.isIdentifier(left.property)
    found = []
    path.get('right').traverse(
      (if t.isIdentifier left
        {name} = left
        [findFirstIdentifierUseInMemberExpression, {name, found}]
      else
        [findFirstMemberExpressionUseInMemberExpression, {memberExpr: left, found}]
      )...
    )
    if found.length
      [found] = found
      found.optional = yes
      return yes
    no

  visitor: withNullReturnValues
    VariableDeclaration: (path) ->
      {node: {declarations}} = path
      assigns =
        declarations
        .filter ({init}) -> init
        .map ({id, init}) -> t.expressionStatement t.assignmentExpression '=', id, init
      path.replaceWithMultiple assigns
    FunctionDeclaration: (path) ->
      {node: {id, params, body, generator, async}} = path
      path.replaceWith(
        t.assignmentExpression(
          '='
          id
          t.functionExpression null, params, body, generator, async
        )
      )
    ArrowFunctionExpression: (path) ->
      {node: {params, body, generator, async}} = path
      path.replaceWith(
        t.functionExpression null, params,
          if t.isBlockStatement body
            body
          else
            t.blockStatement [t.expressionStatement body]
          generator, async
      )
    ForStatement: (path) ->
      {node: {init, test, update, body}} = path

      path.get('body').pushContainer 'body', t.expressionStatement update
      unless init
        path.replaceWith(
          t.whileStatement test, body
        )
      else
        path.replaceWithMultiple [
          init
          t.whileStatement test, body
        ]
    ReturnStatement: (path) ->
      {node: {argument}, node, parentPath} = path

      if parentPath.isBlockStatement() and parentPath.parentPath.isFunction()
        if node is parentPath.node.body[parentPath.node.body.length - 1]
          path.replaceWith argument
    BinaryExpression: (path) ->
      {node: {operator}, node} = path
      node.operator = 'is' if operator is '==='
      node.operator = 'isnt' if operator is '!=='
    LogicalExpression:
      enter: (path) ->
        {node: {left, right, operator}, node} = path
        node.operator = 'and' if operator is '&&'
        node.operator = 'or' if operator is '||'
        if couldBeIn node
          return path.replaceWith t.BinaryExpression 'in', left.left, t.ArrayExpression [left.right, right.right]
        if guardingAnd path
          return path.replaceWith right
      exit: (path) ->
        {node: {left, right}, node} = path
        if couldBeMergedIn node
          path.replaceWith t.BinaryExpression 'in', left.left, t.ArrayExpression [left.right.elements..., right.right]
    IfStatement: (path) ->
      {node: {test, consequent, alternate}, node} = path
      if t.isUnaryExpression test, operator: '!'
        node.test = test.argument
        node.inverted = yes
      if not alternate and t.isBlockStatement(consequent) and consequent.body.length is 1 and t.isReturnStatement(consequent.body[0])
        node.postfix = yes
        node.consequent = consequent.body[0]
    ConditionalExpression: (path) ->
      {node: {test}, node} = path
      if t.isUnaryExpression test, operator: '!'
        node.test = test.argument
        node.inverted = yes
    BooleanLiteral: (path) ->
      {node} = path
      node.name =
        if node.value
          'yes'
        else
          'no'
    SwitchCase: (path) ->
      {node: {consequent}, node} = path
      if consequent.length is 1 and t.isBlockStatement consequent[0]
        node.consequent = consequent[0].body
    UnaryExpression: (path) ->
      {node: {operator, argument}, node, parent} = path
      node.operator = 'not' if operator is '!' and not t.isUnaryExpression(argument, operator: '!') and not t.isUnaryExpression(parent, operator: '!')

transform = (input) ->
  # ast = babylon.parse input, sourceType: 'module', ranges: yes
  {ast: transformed} = babel.transform input,
    plugins: [transformer]
    code: no
    ast: yes
    parserOpts:
      ranges: yes

  # dump {transformed}
  prettier.__debug.formatAST transformed,
    parser: 'coffeescript'
    originalText: input
    bracketSpacing: no
    singleQuote: yes
  .formatted

module.exports = {transform}

dump = (args..., obj) ->
  console.log args..., require('util').inspect obj, no, null
