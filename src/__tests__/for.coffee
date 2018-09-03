{transformed} = require '../test_helper'

test 'basic for-of', ->
  transformed(
    '''
      for (a of b)
        c
    '''
    '''
      for a from b
        c
    '''
  )

test 'basic for-in', ->
  transformed(
    '''
      for (a in b)
        c
    '''
    '''
      for a of b
        c
    '''
  )

test 'for-of with declared loop variable', ->
  transformed(
    '''
      for (const a of b)
        c
    '''
    '''
      for a from b
        c
    '''
  )

test 'for-in with declared loop variable', ->
  transformed(
    '''
      for (let a in b)
        c
    '''
    '''
      for a of b
        c
    '''
  )
