# babylon = require 'babylon'
babel = require '@babel/core'
prettier = require 'prettier'
{mapValues} = require 'lodash/fp'
{last, isArray} = require 'lodash'
{assign: extend} = require 'lodash'

{override: overrideBabelTypes} = require './override-babel-types'

withNullReturnValues = mapValues (f) ->
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

COFFEE_KEYWORDS = [
  'undefined'
  'Infinity'
  'NaN'
  'then'
  'unless'
  'until'
  'loop'
  'of'
  'by'
  'when'
  'and'
  'or'
  'is'
  'isnt'
  'not'
  'yes'
  'no'
  'on'
  'off'
]

transformer = ({types: t}) ->
  isSameIdentifier = (a, b) ->
    t.isIdentifier(a) and t.isIdentifier(b) and a.name is b.name

  isSameNumber = (a, b) ->
    t.isNumericLiteral(a) and t.isNumericLiteral(b) and a.value is b.value

  isAddition = (node) ->
    t.isBinaryExpression node, operator: '+'

  isOr = (node) ->
    t.isLogicalExpression(node) and node.operator in ['||', 'or']

  isNot = (node) ->
    t.isUnaryExpression(node) and node.operator in ['!', 'not']

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
        candidate = if isAddition current
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
    else
      return no
    lastQuasiIndex = quasis.length - 1
    t.templateLiteral(
      quasis.map (quasi, index) ->
        t.templateElement {raw: quasi.value}, index is lastQuasiIndex
    ,
      expressions
    )

  isSameMemberExpression = (first, second) ->
    a = first
    b = second
    loop
      return yes if isSameIdentifier a, b
      return no unless (
        t.isMemberExpression(a) and
        t.isMemberExpression(b) and
        (isSameIdentifier(a.property, b.property) or
          isSameNumber(a.property, b.property)) and
        a.computed is b.computed
      )
      a = a.object
      b = b.object

  couldBeIn = ({operator, left, right}) ->
    return no unless operator is 'or'
    return no unless (
      t.isBinaryExpression(left, operator: '===') and
      t.isBinaryExpression right, operator: '==='
    )
    # return no unless t.isStringLiteral(left.right) and t.isStringLiteral right.right
    return no unless isSameMemberExpression left.left, right.left
    yes

  isEquality = (node) ->
    {operator} = node
    t.isBinaryExpression(node) and operator in ['is', '===']

  couldBeMergedIn = ({operator, left, right}) ->
    return no unless operator is 'or'
    t.isBinaryExpression(right, operator: 'in') and
      t.isArrayExpression(right.right) and
      isEquality(left) and
      isSameMemberExpression left.left, right.left

  isGuard = (left, right) ->
    return no unless t.isIdentifier(left) or t.isMemberExpression left
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
        if parent.type is 'MemberExpression'
          parent.object = left
        else if parent.type is 'CallExpression'
          parent.callee = left
        return yes
      parent = nextParent
  guardingAnd = (path) ->
    {node: {operator, left, right}} = path
    return no unless operator is 'and'
    isGuard left, right
  guardingOr = (path) ->
    {node: {left, right}, node} = path
    return no unless isOr node
    return no unless isNot left
    return no unless isNot right
    isGuard left.argument, right.argument
  notToUnless = (node) ->
    {test} = node
    if (
      t.isUnaryExpression(test, operator: '!') or
      t.isUnaryExpression test, operator: 'not'
    )
      node.test = test.argument
      node.inverted = yes
    else if t.isBinaryExpression test, operator: 'isnt'
      test.operator = 'is'
      node.inverted = yes

  transformForInOf = ({style}) -> (path) ->
    {node: {left, right, body}, node} = path

    path.replaceWith(
      withLocation(node) {
        type: 'For'
        source: right
        name: left
        style
        body
      }
    )

  getFunctionDeclarationAssignment = ({
    node: {id, params, body, generator, async}
    node
  }) ->
    functionExpression =
      withLocation(node, after: id)(
        t.functionExpression null, params, body, generator, async
      )
    withLocation(node)(
      if id?
        t.assignmentExpression '=', id, functionExpression
      # export default anonymous function
      else
        functionExpression
    )

  getFunctionParent = (path) ->
    currentPath = path?.parentPath
    prevPath = path
    while currentPath
      {node: currentNode} = currentPath
      if t.isFunction(currentNode) or t.isProgram currentNode
        return functionParentPath: currentPath, statementPath: prevPath
      prevPath = currentPath
      currentPath = currentPath.parentPath

  createStringLiteral = (value) ->
    node = t.stringLiteral value
    node.extra =
      raw: "'#{value}'" # TODO: escape quotes if need be (or make Prettier plugin ok with extra.raw not being present)
    node

  classesStack = []
  thisContextsStack = []
  switchStatementsStack = []
  visitClass =
    enter: (path) ->
      classesStack.push {}
      thisContextsStack.push {path}
    exit: (path) ->
      thisContextsStack.pop()
      {getterSetterProperties} = classesStack.pop()
      for propertyName, propertyConfig of getterSetterProperties
        location = propertyConfig.get ? propertyConfig.set
        withLoc = withLocation location
        objectDefinePropertyCall = withLoc(
          t.callExpression(
            withLoc(
              t.memberExpression(
                withLoc t.identifier 'Object'
                withLoc t.identifier 'defineProperty'
              )
            )
            [
              withLoc(
                t.memberExpression(
                  withLoc t.thisExpression()
                  withLoc t.identifier 'prototype'
                )
              )
              withLoc createStringLiteral propertyName
              withLoc(
                t.objectExpression(
                  for getterSetterName, getterSetterFunction of propertyConfig
                    withLoc(
                      t.objectProperty(
                        withLoc t.identifier getterSetterName
                        getterSetterFunction
                      )
                    )
                )
              )
            ]
          )
        )
        path.get('body').pushContainer 'body', objectDefinePropertyCall

  visitor: withNullReturnValues(
    ExportDefaultDeclaration: (path) ->
      {node: {declaration}, node} = path
      if declaration?.type is 'FunctionDeclaration'
        return path.replaceWith(
          withLocation(node)(
            t.exportDefaultDeclaration(
              getFunctionDeclarationAssignment node: declaration
            )
          )
        )
    ExportNamedDeclaration: (path) ->
      {node: {declaration, specifiers, source}, node} = path
      if declaration?.type is 'VariableDeclaration'
        {declarations: [{id, init}]} = declaration
        return path.replaceWith(
          withLocation(node)(
            t.exportNamedDeclaration(
              withLocation(node) t.assignmentExpression '=', id, init
              specifiers
              source
            )
          )
        )
      if declaration?.type is 'FunctionDeclaration'
        return path.replaceWith(
          withLocation(node)(
            t.exportNamedDeclaration(
              getFunctionDeclarationAssignment node: declaration
              specifiers
              source
            )
          )
        )
    VariableDeclaration: (path) ->
      {node: {declarations}, parentPath} = path
      if parentPath.node.type in ['ForInStatement', 'ForOfStatement']
        return path.replaceWith declarations[0].id
      assigns = declarations
        # .filter ({init}) -> init
        .map (node) ->
          {id, init} = node
          withLocation(node)(
            t.expressionStatement(
              withLocation(node)(
                t.assignmentExpression '=', id, init ? t.identifier 'undefined'
              )
            )
          )
      path.replaceWithMultiple assigns
    FunctionDeclaration:
      enter: (path) ->
        {node: {id}, node, scope} = path
        thisContextsStack.push {path}

        functionAssignment =
          withLocation(node)(
            t.expressionStatement getFunctionDeclarationAssignment {node}
          )
        earliestPrecedingReference = null
        if id?
          binding = scope.getBinding id.name
          {block: bindingScopeBlock} = binding.scope
          {referencePaths} = binding
          for referencePath in referencePaths
            {node: referenceNode} = referencePath
            continue unless referenceNode.start < id.start
            continue unless (
              not earliestPrecedingReference? or
              referenceNode.start < earliestPrecedingReference.path.node.start
            )
            {
              functionParentPath: referenceFunctionParentPath
              statementPath: referenceStatementParentPath
            } = getFunctionParent referencePath
            continue unless (
              bindingScopeBlock is referenceFunctionParentPath?.node
            )
            earliestPrecedingReference =
              path: referencePath
              functionParentPath: referenceFunctionParentPath
              statementParentPath: referenceStatementParentPath
        if earliestPrecedingReference?
          # earliestPrecedingReference.statementParentPath.insertBefore(
          #   functionAssignment
          # )
          referenceStart = earliestPrecedingReference.path.node.start
          functionBody = earliestPrecedingReference.functionParentPath.node.body
          functionBodyPath = 'body'
          if not isArray(functionBody) and functionBody.body?
            functionBody = functionBody.body
            functionBodyPath = 'body.body'
          for statementNode, statementIndex in functionBody
            statementPath = earliestPrecedingReference.functionParentPath.get(
              "#{functionBodyPath}.#{statementIndex}"
            )
            if (
              statementNode.start <= referenceStart and
              statementNode.end >= referenceStart
            )
              path.remove()
              statementPath.insertBefore functionAssignment
              break
        else
          path.replaceWith functionAssignment
      exit: ->
        thisContextsStack.pop()
    FunctionExpression:
      enter: (path) ->
        thisContextsStack.push {path}
      exit: ->
        thisContextsStack.pop()
    ArrowFunctionExpression:
      enter: (path) ->
        {node: {body}, node} = path
        thisContextsStack.push {path}
        unless t.isBlockStatement body
          node.body =
            withLocation(body)(
              t.blockStatement [withLocation(body) t.expressionStatement body]
            )
      exit: (path) ->
        {node} = path
        {thisReferences} = thisContextsStack.pop()
        unless thisReferences?.length
          node.type = 'FunctionExpression'
    ClassDeclaration: visitClass
    ClassExpression: visitClass
    ClassMethod: (path) ->
      {node: {kind, key, params, body, generator, async}, node} = path
      if kind in ['get', 'set']
        klass = last classesStack
        klass.getterSetterProperties ?= {}
        {getterSetterProperties} = klass
        if (
          t.isIdentifier key # TODO: handle computed key
        )
          propertyDescription = getterSetterProperties[key.name] ?= {}
          propertyDescription[kind] =
            withLocation(node)(
              t.functionExpression null, params, body, generator, async
            )
        path.remove()

    ForStatement: (path) ->
      {node: {init, test, update, body}, node} = path

      path.get('body').pushContainer 'body', t.expressionStatement update
      unless init
        path.replaceWith withLocation(node) t.whileStatement test, body
      else
        path.replaceWithMultiple [
          init
          withLocation(node) t.whileStatement test, body
        ]
    ForOfStatement:
      exit: transformForInOf style: 'from'
    ForInStatement:
      exit: transformForInOf style: 'of'
    ObjectMethod: (path) ->
      {node: {key, computed, params, body}, node} = path

      path.replaceWith(
        withLocation(node)(
          t.objectProperty(
            key
            withLocation(node) t.functionExpression null, params, body
            computed
          )
        )
      )
    ReturnStatement: (path) ->
      {node: {argument}, node, parentPath} = path

      if parentPath.isBlockStatement() and parentPath.parentPath.isFunction()
        if node is parentPath.node.body[parentPath.node.body.length - 1]
          path.replaceWith withLocation(argument) t.expressionStatement argument
    BinaryExpression:
      enter: (path) ->
        {node: {operator}, node} = path
        node.operator = 'is' if operator is '==='
        node.operator = 'isnt' if operator is '!=='
        node.operator = 'of' if operator is 'in' and not node._in

      exit: (path) ->
        {node: {operator, left, right}, node} = path
        if (
          operator in ['==', '!='] and
          (left.type is 'NullLiteral' or right.type is 'NullLiteral')
        )
          expr = if left.type is 'NullLiteral' then right else left
          existence = withLocation(node) t.unaryExpression '?', expr, no
          return path.replaceWith(
            if operator is '!='
              existence
            else
              withLocation(node) t.unaryExpression 'not', existence
          )

    ThisExpression: (path) ->
      {node} = path
      node.shorthand = yes

      [..., thisContext] = thisContextsStack
      if thisContext?
        (thisContext.thisReferences ?= []).push path
    LogicalExpression:
      enter: (path) ->
        {node: {left, right, operator}, node} = path
        node.operator = 'and' if operator is '&&'
        node.operator = operator = 'or' if operator is '||'
        if couldBeIn node
          return path.replaceWith(
            withLocation(node)(
              extend(
                t.BinaryExpression(
                  'in'
                  left.left
                  t.ArrayExpression [left.right, right.right]
                )
                _in: yes
              )
            )
          )
        else if couldBeMergedIn node
          path.replaceWith(
            withLocation(node)(
              extend(
                t.BinaryExpression(
                  'in'
                  left.left
                  t.ArrayExpression [left.right, right.right.elements...]
                )
                _in: yes
              )
            )
          )
        else if isOr(left) and couldBeIn {operator, left: left.right, right}
          return path.replaceWith(
            withLocation(node)(
              t.LogicalExpression(
                '||' # 'or',
                left.left
                extend(
                  t.BinaryExpression(
                    'in'
                    left.right.left
                    t.ArrayExpression [left.right.right, right.right]
                  )
                  _in: yes
                )
              )
            )
          )
        else if (
          isOr(left) and couldBeMergedIn {operator, left: left.right, right}
        )
          return path.replaceWith(
            withLocation(node)(
              t.LogicalExpression(
                '||'
                left.left
                extend(
                  t.BinaryExpression(
                    'in'
                    left.right.left
                    t.ArrayExpression [
                      left.right.right
                      right.right.elements...
                    ]
                  )
                  _in: yes
                )
              )
            )
          )
      exit: (path) ->
        {node: {right}} = path
        if guardingAnd path
          return path.replaceWith right
        if guardingOr path
          return path.replaceWith right
    IfStatement:
      exit: (path) ->
        {node: {consequent, alternate, test}, node} = path
        notToUnless node
        isSingleBody = (condition) ->
          if (
            t.isBlockStatement(consequent) and
            consequent.body.length is 1 and
            condition consequent.body[0]
          )
            return consequent.body[0]
          if condition consequent
            return consequent
        singleReturnContinueOrBreak = isSingleBody (expr) ->
          t.isReturnStatement(expr) or
          t.isContinueStatement(expr) or
          t.isBreakStatement expr

        if not alternate and singleReturnContinueOrBreak?
          node.postfix = yes
          node.consequent = singleReturnContinueOrBreak

        if (
          not alternate? and
          t.isBlockStatement(consequent) and
          consequent.body.length is 1 and
          consequent.body[0].type is 'ExpressionStatement'
        )
          if isGuard test, consequent.body[0].expression
            return path.replaceWith consequent.body[0]
    ConditionalExpression: (path) ->
      {node} = path
      notToUnless node
    BooleanLiteral: (path) ->
      {node} = path
      node.name = if node.value
        'yes'
      else
        'no'
    SwitchStatement:
      enter: ->
        switchStatementsStack.push currentFallthroughCases: []
      exit: ->
        switchStatementsStack.pop()
    SwitchCase:
      enter: (path) ->
        {node: {consequent}, node} = path
        if consequent.length is 1 and t.isBlockStatement consequent[0]
          node.consequent = consequent[0].body
        {consequent} = node
        [..., lastStatement] = consequent
        [..., switchStatement] = switchStatementsStack
        {currentFallthroughCases} = switchStatement
        isLastCase = node is last path.parentPath.node.cases
        if (
          lastStatement? and
          not isLastCase and
          not t.isBreakStatement(lastStatement) and
          not t.isReturnStatement lastStatement
        )
          currentFallthroughCases.push path
        else if lastStatement? or isLastCase
          if t.isBreakStatement lastStatement
            path.get("consequent.#{consequent.length - 1}").remove()
          for currentFallthroughCase, currentFallthroughCaseIndex in (
            currentFallthroughCases
          )
            for followingFallthroughCase in (
              currentFallthroughCases[(currentFallthroughCaseIndex + 1)..]
            )
              for followingFallthroughStatement in (
                followingFallthroughCase.node.consequent
              )
                currentFallthroughCase.pushContainer(
                  'consequent'
                  followingFallthroughStatement
                )
            for statement in consequent
              currentFallthroughCase.pushContainer 'consequent', statement
          switchStatement.currentFallthroughCases = []
        # TODO: in theory someone could have an empty fallthrough to default eg case 'c': default: {...}
        # which should treat 'c' as a currentFallthroughCase (ie copy the default block into 'c')

    UnaryExpression: (path) ->
      {node: {operator, argument}, node, parent} = path
      node.operator = 'not' if (
        operator is '!' and
        not t.isUnaryExpression(argument, operator: '!') and
        not t.isUnaryExpression parent, operator: '!'
      )
      if (
        node.operator is 'void' and
        node.argument.type is 'NumericLiteral' and
        node.argument.value is 0
      )
        path.replaceWith(
          withLocation(node)
            type: 'Identifier'
            name: 'undefined'
        )
    TemplateLiteral: (path) ->
      {node: {quasis}, node} = path
      isMultiline = no
      for quasi in quasis
        quasi.value.raw = quasi.value.raw.replace /(?!\\)"/g, '\\"'
        isMultiline = yes if /\n/.test quasi.value.raw
      node.quote = '"""' if isMultiline
    NewExpression: (path) ->
      {node: {callee, arguments: args}, node} = path
      if (
        t.isIdentifier(callee, name: 'RegExp') and
        args.length is 1 and
        (templateLiteral = additionToTemplateLiteral args[0])
      )
        path.replaceWith(
          withLocation(node)
            type: 'RegExpLiteral'
            interpolatedPattern: templateLiteral
            delimiter: '///'
            flags: ''
        )
    MemberExpression: (path) ->
      {node: {property}, node} = path
      if t.isIdentifier property, name: 'prototype'
        node.shorthand = yes
    Identifier: (path) ->
      {node: {name}, scope} = path
      if (
        name in COFFEE_KEYWORDS and
        # path.isReferencedIdentifier() and
        scope.hasBinding name # TODO: should warn about non-declared names (except "global" name eg undefined, NaN, Infinity?
      )
        scope.rename name

      unless t.isClassDeclaration scope.block
        ownBinding = scope.getOwnBinding name
        outerBinding = scope.parent?.getBinding name
        if ownBinding and outerBinding and ownBinding.kind isnt 'param'
          scope.rename name
    BlockStatement: (path) ->
      {node} = path
      node.loc.start.line += 1
  )

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
  value.replace(/\n\s*\*/g, '\n#').replace /\n\s*$/, '\n'

transform = (input) ->
  overrideBabelTypes()
  # ast = babylon.parse input, sourceType: 'module', ranges: yes
  # dump {ast}
  {ast: transformed} = babel.transform input,
    plugins: [transformer]
    code: no
    ast: yes
    parserOpts: ranges: yes

  # dump {transformed}
  if (
    transformed.comments # TODO: figure out where/why this actually should happen
  )
    transformed.comments = for comment in transformed.comments
      {
        ...comment
        range: [comment.start, comment.end]
        value: transformCommentValue comment.value
      }
  prettier.__debug.attachCommentsAndFormatAST(
    transformed
    parser: 'coffeescript'
    pluginSearchDirs: ['.']
    originalText: input
    bracketSpacing: no
    singleQuote: yes
  ).formatted

module.exports = {transform}

resetLogColors = ->
  {styles, colors} = require('util').inspect
  colors.normal = [39, 39]
  styles.string = 'yellow'
  styles.number = 'normal'
  styles.boolean = 'normal'
  styles.null = 'normal'
resetLogColors()
# dump = (obj) => console.log require('util').inspect obj, false, null
