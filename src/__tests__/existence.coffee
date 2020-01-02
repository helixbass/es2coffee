{transformed} = require '../test_helper'

test 'simple == null -> existence', ->
  transformed 'a == null', 'not a?'

  transformed 'a != null', 'a?'

  transformed 'null != a', 'a?'

test 'condition', ->
  transformed(
    '''
      if (a != null) {
        b
      }
    '''
    '''
      if a? then b
    '''
  )

test 'inverted condition', ->
  transformed(
    '''
      if (a == null) {
        b
      }
    '''
    '''
      unless a? then b
    '''
  )

test 'return', ->
  transformed(
    '''
      const x = function() {
        if (a == null) {
          return
        }
        b
      }
    '''
    '''
      x = ->
        return unless a?
        b
    '''
  )

  transformed(
    '''
      const x = function() {
        if (a == null) return
        b
      }
    '''
    '''
      x = ->
        return unless a?
        b
    '''
  )

  transformed(
    '''
      const x = function() {
        if (a != null) {
          return
        }
        b
      }
    '''
    '''
      x = ->
        return if a?
        b
    '''
  )
