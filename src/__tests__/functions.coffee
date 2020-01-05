{transformed} = require '../test_helper'

test 'generates skinny arrow if `this` not used', ->
  transformed(
    '''
      const x = () => 3
    '''
    '''
      x = -> 3
    '''
  )

test 'generates fat arrow if `this` is used', ->
  transformed(
    '''
      const x = () => f(this)
    '''
    '''
      x = =>
        f @
    '''
  )

test 'generates skinny arrow by default', ->
  transformed(
    '''
      const x = function() {
        return this.y
      }
    '''
    '''
      x = -> @y
    '''
  )

describe 'hoisting named functions with preceding static references', ->
  test 'hoists named function which is invoked statically further up', ->
    transformed(
      '''
        var a = b()

        function b() {
          return 'here'
        }
      '''
      '''
        b = -> 'here'
        a = b()
      '''
    )

  test 'hoists nested named function which is invoked statically further up', ->
    transformed(
      '''
        const x = () => {
          var a = b()

          function b() {
            return 'here'
          }
        }
      '''
      '''
        x = ->
          b = -> 'here'
          a = b()
      '''
    )

  test "doesn't hoist named function which is invoked non-statically further up", ->
    transformed(
      '''
        var a = () => b()

        function b() {
          return 'here'
        }
      '''
      '''
        a = ->
          b()

        b = -> 'here'
      '''
    )

  test 'hoists named function which is invoked statically inside if block further up', ->
    transformed(
      '''
        if (true) {
          b()
        }

        function b() {
          console.log('here')
        }
      '''
      '''
        b = ->
          console.log 'here'
        if yes
          b()
      '''
    )

  test 'hoists nested named function which is invoked statically inside if block further up', ->
    transformed(
      '''
        function a() {
          if (true) {
            b()
          }

          function b() {
            console.log('here')
          }
        }
      '''
      '''
        a = ->
          b = ->
            console.log 'here'
          if yes
            b()
      '''
    )

  test 'hoists multiple named functions which are invoked statically further up', ->
    transformed(
      '''
        var a = b()
        var c = d()

        function b() {
          return 'here'
        }

        function d() {
          return 'there'
        }
      '''
      '''
        b = -> 'here'

        a = b()
        d = -> 'there'
        c = d()
      '''
    )

test 'handles export default anonymous function', ->
  transformed(
    '''
      export default function() {
        return 1
      }
    '''
    '''
      export default -> 1
    '''
  )

describe 'return value', ->
  test 'returns undefined for functions without return value', ->
    transformed(
      '''
        const x = function() {
          y()
        }
        doSomethingWith(x)
      '''
      '''
        x = ->
          y()
          undefined
        doSomethingWith x
      '''
    )

  test "doesn't return undefined for unassigned do-iife functions without return value", ->
    transformed(
      '''
        function b() {
          (function() {
            y()
          })()
        }
      '''
      '''
        b = ->
          do ->
            y()
      '''
    )

  test "doesn't return undefined for assigned functions whose calls' return values are all ignored", ->
    transformed(
      '''
        function b() {
          x()
        }

        b()
      '''
      '''
        b = ->
          x()

        b()
      '''
    )

  test "returns undefined for assigned functions not all of whose calls' return values are all ignored", ->
    transformed(
      '''
        function b() {
          x()
        }

        b()
        x = b()
      '''
      '''
        b = ->
          x()
          undefined

        b()
        x = b()
      '''
    )

  test "doesn't returns undefined for constructor", ->
    transformed(
      '''
        class A {
          constructor() {
            this.x = 1;
          }
        }
      '''
      '''
        class A
          constructor: ->
            @x = 1
      '''
    )
