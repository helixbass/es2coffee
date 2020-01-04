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
      x = => f @
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
          console.log('here')
        }
      '''
      '''
        b = -> console.log 'here'
        a = b()
      '''
    )

  test 'hoists nested named function which is invoked statically further up', ->
    transformed(
      '''
        const x = () => {
          var a = b()

          function b() {
            console.log('here')
          }
        }
      '''
      '''
        x = ->
          b = -> console.log 'here'
          a = b()
      '''
    )

  test "doesn't hoist named function which is invoked non-statically further up", ->
    transformed(
      '''
        var a = () => b()

        function b() {
          console.log('here')
        }
      '''
      '''
        a = -> b()

        b = -> console.log 'here'
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
        b = -> console.log 'here'
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
          b = -> console.log 'here'
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
          console.log('here')
        }

        function d() {
          console.log('there')
        }
      '''
      '''
        b = -> console.log 'here'

        a = b()
        d = -> console.log 'there'
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
