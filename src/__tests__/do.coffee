{transformed} = require '../test_helper'

test 'iife with no args -> do', ->
  transformed(
    '''
      const y = function() {
        return x()
      }()
    '''
    '''
      y = do ->
        x()
    '''
  )

test 'strip top-level iife', ->
  transformed(
    '''
      (function() {
        x()
      })()
    '''
    '''
      x()
    '''
  )
test "don't strip top-level iife with args", ->
  transformed(
    '''
      (function(_this) {
        x()
      })(this)
    '''
    '''
      ((_this) ->
        x()
      ) @
    '''
  )

test 'preserve directives when stripping top-level iife', ->
  transformed(
    '''
      (function() {
        'use strict'
        x()
      })()
    '''
    '''
      'use strict'
      x()
    '''
  )
