{transformed} = require '../test_helper'

test 'renames Coffeescript-only keyword declared variable names', ->
  transformed(
    '''
      const no = 1

      x(no)
    '''
    '''
      _no = 1

      x _no
    '''
  )

test 'leaves alone non-declared names', ->
  transformed(
    '''
      Infinity
    '''
    '''
      Infinity
    '''
  )

test 'renames shadowed const variable', ->
  transformed(
    '''
      const x = 1
      x + 3

      if (true) {
        const x = 2
        x * 2
      }
    '''
    '''
      x = 1
      x + 3

      if yes
        _x = 2
        _x * 2
    '''
  )

test 'renames shadowed let variable', ->
  transformed(
    '''
      let x = 1
      x + 3

      if (true) {
        let x = 2
        x * 2
      }
    '''
    '''
      x = 1
      x + 3

      if yes
        _x = 2
        _x * 2
    '''
  )

test 'renames shadowed var variable', ->
  transformed(
    '''
      var x = 1
      x + 3

      f(() => {
        var x = 2
        x * 2
      })
    '''
    '''
      x = 1
      x + 3

      f ->
        _x = 2
        _x * 2
    '''
  )

test "doesn't rename shadowed param", ->
  transformed(
    '''
      const x = 1
      x + 3

      const y = function(x) {
        return x;
      }

      a(({x}) => x)
    '''
    '''
      x = 1
      x + 3

      y = (x) -> x

      a ({x}) -> x
    '''
  )

describe 'initialization', ->
  test 'initializes uninitialized variables by default', ->
    transformed(
      '''
        var a, b;

        f(a, b)
      '''
      '''
        a = undefined
        b = undefined

        f a, b
      '''
    )

  test "doesn't initialize uninitialized variables if initial use is write (in same scope)", ->
    transformed(
      '''
        var a, b;

        a = 1
        f(a, b)
      '''
      '''
        b = undefined

        a = 1
        f a, b
      '''
    )

  test "doesn't initialize uninitialized variables if initial use is write in nested non-function scope", ->
    transformed(
      '''
        var a, b;

        if (true) {
          a = 1
        }
        f(a, b)
      '''
      '''
        b = undefined

        if yes
          a = 1
        f a, b
      '''
    )

    transformed(
      '''
        var a, b;

        (function() {
          a = 1
        })()
        f(a, b)
      '''
      '''
        a = undefined
        b = undefined

        do -> a = 1
        f a, b
      '''
    )
