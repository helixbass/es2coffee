{transformed} = require '../test_helper'

test 'generates or for ||', ->
  transformed(
    '''
      a || b
    '''
    '''
      a or b
    '''
  )

test 'generates or for || in inverted condition', ->
  transformed(
    '''
      const x = () => {
        return !(a || b)
      }
    '''
    '''
      x = ->
        not (a or b)
    '''
  )
