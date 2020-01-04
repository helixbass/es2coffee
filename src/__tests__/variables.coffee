{transformed} = require '../test_helper'

test 'renames Coffeescript-only keyword declared variable names', ->
  transformed(
    '''
      const no = 1
    '''
    '''
      _no = 1
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
