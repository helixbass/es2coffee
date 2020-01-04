{transformed} = require '../test_helper'

test 'iife with no args -> do', ->
  transformed(
    '''
      const y = function() {
        x()
      }()
    '''
    '''
      y = do -> x()
    '''
  )
