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

describe 'for loops', ->
  test 'basic for loop', ->
    transformed(
      '''
        for (let i = 0; i < items.length; i++) {
          const item = items[i]
          b(item);
        }
      '''
      '''
        for item in items
          b item
      '''
    )

  test 'for loop that uses index', ->
    transformed(
      '''
        for (let i = 0; i < items.length; i++) {
          const item = items[i]
          b(item, i);
        }
      '''
      '''
        for item, i in items
          b item, i
      '''
    )

  test 'by default for loop compiles to while', ->
    transformed(
      '''
        for (let i = 0; i === 1; i++) {
          const item = items[i]
          b(item);
        }
      '''
      '''
        i = 0
        while i is 1
          item = items[i]
          b item
          i++
      '''
    )

  test "for loop that doesn't grab item -> range", ->
    transformed(
      '''
        for (let i = 0; i < items.length; i++) {
          b(i);
        }
      '''
      '''
        for i in [0...items.length]
          b i
      '''
    )
