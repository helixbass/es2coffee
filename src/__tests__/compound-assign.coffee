{transformed} = require '../test_helper'

test 'or=', ->
  transformed(
    '''
      options = options || {}
    '''
    '''
      options or= {}
    '''
  )

test 'and=', ->
  transformed(
    '''
      a = a && true
    '''
    '''
      a and= yes
    '''
  )
