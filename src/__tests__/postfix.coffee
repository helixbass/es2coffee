{transformed} = require '../test_helper'

test 'generates postfix if + return', ->
  transformed(
    '''
      const x = () => {
        if (z) {
          return false
        }
        w()
      }
    '''
    '''
      x = ->
        return no if z
        w()
    '''
  )

test "doesn't generate postfix if + return function", ->
  transformed(
    '''
      const x = () => {
        if (z) {
          return () => z
        }
        w()
      }
    '''
    '''
      x = ->
        if z
          return -> z
        w()
    '''
  )
