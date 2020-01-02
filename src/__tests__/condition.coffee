{transformed} = require '../test_helper'

test 'convert !== to unless', ->
  transformed(
    '''
      if (name !== 'default') {
        b
      }
    '''
    '''
      unless name is 'default' then b
    '''
  )

test 'postfix continue/break', ->
  transformed(
    '''
      while (1) {
        if (!innerMap) {
          continue
        }
        b
      }
    '''
    '''
      while 1
        continue unless innerMap
        b
    '''
  )
