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

  isSameNumber = (a, b) ->
    t.isNumericLiteral(a) and t.isNumericLiteral(b) and a.value is b.value

  isAddition = (node) ->
    t.isBinaryExpression node, operator: '+'

  isOr = (node) ->
    t.isLogicalExpression(node) and node.operator in ['||', 'or']

  additionToTemplateLiteral = (node) ->
    return no unless isAddition node
    {left, right} = node

    expressions = []
    quasis = []
    if t.isStringLiteral right
      quasis.unshift right
      next = expressions
      current = left
      loop
        candidate =
          if isAddition current
            current.right
          else
            current
        if next is expressions
          return no if t.isStringLiteral candidate
          expressions.unshift candidate
        else
          return no unless t.isStringLiteral candidate
          quasis.unshift candidate
        break unless isAddition current
        next = if next is expressions then quasis else expressions
        current = current.left
    else return no
    lastQuasiIndex = quasis.length - 1
    t.templateLiteral(
      quasis.map (quasi, index) -> t.templateElement {raw: quasi.value}, index is lastQuasiIndex
      expressions
    )

  isSameMemberExpression = (first, second) ->
    a = first
    b = second
    loop
      return yes if isSameIdentifier a, b
      return no unless t.isMemberExpression(a) and t.isMemberExpression(b) and (isSameIdentifier(a.property, b.property) or isSameNumber(a.property, b.property)) and a.computed is b.computed
      a = a.object
      b = b.object

  couldBeIn = ({operator, left, right}) ->
    return no unless operator is 'or'
    return no unless t.isBinaryExpression(left, operator: '===') and t.isBinaryExpression right, operator: '==='
    # return no unless t.isStringLiteral(left.right) and t.isStringLiteral right.right
    return no unless isSameMemberExpression left.left, right.left
    yes

  isEquality = (node) ->
    {operator} = node
    t.isBinaryExpression(node) and operator in ['is', '===']

  couldBeMergedIn = ({operator, left, right}) ->
    return no unless operator is 'or'
    t.isBinaryExpression(right, operator: 'in') and t.isArrayExpression(right.right) and isEquality(left) and isSameMemberExpression left.left, right.left

  guardingAnd = (path) ->
    {node: {operator, left, right}} = path
    return no unless operator is 'and' and (isIdentifier=t.isIdentifier(left)) or t.isMemberExpression(left)
    current = right
    parent = null
    found = no
    loop
      nextParent = current
      switch current.type
        when 'Identifier', 'MemberExpression'
          if isSameMemberExpression left, current
            return no unless parent
            found = yes
          return no if current.type is 'Identifier' and not found
          current = current.object
        when 'CallExpression'
          current = current.callee
        else
          return no
      if found
        parent.optional = yes
        return yes
      parent = nextParent
    found = []
  notToUnless = (node) ->
    {test} = node
    if t.isUnaryExpression test, operator: '!'
      node.test = test.argument
      node.inverted = yes
    else if t.isBinaryExpression test, operator: '!=='
      test.operator = '==='
      node.inverted = yes

  visitor: withNullReturnValues
    VariableDeclaration: (path) ->
      {node: {declarations}} = path
      assigns =
        declarations
        .filter ({init}) -> init
        .map (node) ->
          {id, init} = node
          withLocation(node) t.expressionStatement t.assignmentExpression '=', id, init
      path.replaceWithMultiple assigns
    FunctionDeclaration: (path) ->
      {node: {id, params, body, generator, async}, node} = path
      path.replaceWith(
        withLocation(node) t.expressionStatement withLocation(node) t.assignmentExpression(
          '='
          id
          withLocation(node, after: id) t.functionExpression null, params, body, generator, async
        )
      )
    ArrowFunctionExpression: (path) ->
      {node: {params, body, generator, async}, node} = path
      path.replaceWith(
        withLocation(node) t.functionExpression null, params,
          if t.isBlockStatement body
            body
          else
            t.blockStatement [t.expressionStatement body]
          generator, async
      )
    ForStatement: (path) ->
      {node: {init, test, update, body}, node} = path

      path.get('body').pushContainer 'body', t.expressionStatement update
      unless init
        path.replaceWith(
          withLocation(node) t.whileStatement test, body
        )
      else
        path.replaceWithMultiple [
          init
          withLocation(node) t.whileStatement test, body
        ]
    ObjectMethod: (path) ->
      {node: {key, computed, params, body}, node} = path

      path.replaceWith(
        withLocation(node) t.objectProperty(
          key
          withLocation(node) t.functionExpression null, params, body
          computed
        )
      )
    ReturnStatement: (path) ->
      {node: {argument}, node, parentPath} = path

      if parentPath.isBlockStatement() and parentPath.parentPath.isFunction()
        if node is parentPath.node.body[parentPath.node.body.length - 1]
          path.replaceWith withLocation(argument) t.expressionStatement argument
    BinaryExpression: (path) ->
      {node: {operator}, node} = path
      node.operator = 'is' if operator is '==='
      node.operator = 'isnt' if operator is '!=='
    LogicalExpression:
      enter: (path) ->
        {node: {left, right, operator}, node} = path
        node.operator = 'and' if operator is '&&'
        node.operator = operator = 'or' if operator is '||'
        if couldBeIn node
          return path.replaceWith withLocation(node) t.BinaryExpression 'in', left.left, t.ArrayExpression [left.right, right.right]
        else if couldBeMergedIn node
          path.replaceWith withLocation(node) t.BinaryExpression 'in', left.left, t.ArrayExpression [left.right, right.right.elements...]
        else if isOr(left) and couldBeIn {operator, left: left.right, right}
          return path.replaceWith withLocation(node) t.LogicalExpression '||', # 'or',
            left.left,
            t.BinaryExpression 'in', left.right.left, t.ArrayExpression [left.right.right, right.right]
        else if isOr(left) and couldBeMergedIn {operator, left: left.right, right}
          return path.replaceWith withLocation(node) t.LogicalExpression '||',
            left.left,
            t.BinaryExpression 'in', left.right.left, t.ArrayExpression [left.right.right, right.right.elements...]
        if guardingAnd path
          return path.replaceWith right
    IfStatement: (path) ->
      {node: {consequent, alternate}, node} = path
      notToUnless node
      if not alternate and t.isBlockStatement(consequent) and consequent.body.length is 1 and t.isReturnStatement(consequent.body[0])
        node.postfix = yes
        node.consequent = consequent.body[0]
    ConditionalExpression: (path) ->
      {node} = path
      notToUnless node
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
    NewExpression: (path) ->
      {node: {callee, arguments: args}, node} = path
      if t.isIdentifier(callee, name: 'RegExp') and args.length is 1 and templateLiteral = additionToTemplateLiteral(args[0])
        path.replaceWith withLocation(node)
          type: 'RegExpLiteral'
          interpolatedPattern: templateLiteral
          delimiter: '///'
          flags: ''

withLocation = (node, {after} = {}) -> (newNode) ->
  for field in ['loc', 'start', 'end', 'range']
    newNode[field] ?= node[field]
  if after?.loc
    newNode.start = after.end
    newNode.range[0] = after.range[1]
    newNode.loc.start = after.loc.end
  newNode

# TODO: refine a lot
transformCommentValue = (value) ->
  value
  .replace /\n\s*\*/g, "\n#"
  .replace /\n\s*$/, "\n"

transform = (input) ->
  # ast = babylon.parse input, sourceType: 'module', ranges: yes
  {ast: transformed} = babel.transform input,
    plugins: [transformer]
    code: no
    ast: yes
    parserOpts:
      ranges: yes

  # dump {transformed}
  if transformed.comments # TODO: figure out where/why this actually should happen
    transformed.comments =
      for comment in transformed.comments
        {
          ...comment
          range: [comment.start, comment.end]
          value: transformCommentValue comment.value
        }
  prettier.__debug.attachCommentsAndFormatAST transformed,
    parser: 'coffeescript'
    originalText: input
    bracketSpacing: no
    singleQuote: yes
  .formatted

module.exports = {transform}

resetLogColors = ->
  {styles, colors} = require('util').inspect
  colors.normal = [39, 39]
  styles.string = 'yellow'
  styles.number = 'normal'
  styles.boolean = 'normal'
  styles.null = 'normal'
resetLogColors()
dump = (args..., obj) ->
  console.log args..., require('util').inspect obj, no, null
