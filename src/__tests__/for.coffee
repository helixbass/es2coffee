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

  test 'for loop with pre-declared index', ->
    transformed(
      '''
        var i;
        for (i = 0; i < items.length; i++) {
          const item = items[i]
          b(item);
        }
      '''
      '''
        for item in items
          b item
      '''
    )

  describe 'length caching', ->
    describe 'loop-declared variables', ->
      test 'for loop that caches length', ->
        transformed(
          '''
            for (let i = 0, iz = items.length; i < iz; ++i) {
              const item = items[i]
              b(item);
            }
          '''
          '''
            for item in items
              b item
          '''
        )

      test 'for loop that caches length -> range', ->
        transformed(
          '''
            for (let i = 0, iz = items.length; i < iz; ++i) {
              b(items[i + 1]);
            }
          '''
          '''
            for i in [0...items.length]
              b items[i + 1]
          '''
        )

      test 'for loop that caches length -> range + assignment', ->
        transformed(
          '''
            for (let i = 0, iz = items.length; i < iz; ++i) {
              b(items[i + 1 - iz]);
            }
          '''
          '''
            for i in [0...(iz = items.length)]
              b items[i + 1 - iz]
          '''
        )

    describe 'predeclared variables', ->
      test 'for loop that caches length', ->
        transformed(
          '''
            var i, iz;

            for (i = 0, iz = items.length; i < iz; ++i) {
              const item = items[i]
              b(item);
            }
          '''
          '''
            for item in items
              b item
          '''
        )

      test 'for loop that caches length -> range', ->
        transformed(
          '''
            let i, iz;
            for (i = 0, iz = items.length; i < iz; ++i) {
              b(items[i + 1]);
            }
          '''
          '''
            for i in [0...items.length]
              b items[i + 1]
          '''
        )

      test 'for loop that caches length -> range + assignment', ->
        transformed(
          '''
            var i, iz;
            for (i = 0, iz = items.length; i < iz; ++i) {
              b(items[i + 1 - iz]);
            }
          '''
          '''
            for i in [0...(iz = items.length)]
              b items[i + 1 - iz]
          '''
        )

  describe 'guard', ->
    test 'guarding if -> when', ->
      transformed(
        '''
          for (let i = 0; i < items.length; i++) {
            const item = items[i]
            if (item != null) {
              b(item);
            }
          }
        '''
        '''
          for item in items when item?
            b item
        '''
      )

    test 'multiple nested guarding if -> when', ->
      transformed(
        '''
          for (let i = 0; i < items.length; i++) {
            const item = items[i]
            if (item != null) {
              if (b) {
                b(item);
              }
            }
          }
        '''
        '''
          for item in items when item? and b
            b item
        '''
      )

    test 'guarding if -> when range', ->
      transformed(
        '''
          for (let i = 0; i < items.length; i++) {
            if (i !== 1) {
              b(i + 1);
            }
          }
        '''
        '''
          for i in [0...items.length] when i isnt 1
            b i + 1
        '''
      )
