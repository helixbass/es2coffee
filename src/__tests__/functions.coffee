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
