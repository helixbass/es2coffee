{transformed} = require '../test_helper'

test 'removes break from switch cases', ->
  transformed(
    '''
      switch (b) {
        case 'c':
          3;
          break;
      }
    '''
    '''
      switch b
        when 'c'
          3
    '''
  )

test 'preserves non-switch break', ->
  transformed(
    '''
      while (true) {
        break
      }
    '''
    '''
      while yes
        break
    '''
  )

test 'preserves nontrailing break in switch case', ->
  transformed(
    '''
      switch (specifier.type) {
        case 'ImportSpecifier': {
          const meta = xyz
          if (!meta || !meta.namespace) break
          namespaces.set(specifier.local.name, meta.namespace)
          break 
        }
      }
    '''
    '''
      switch specifier.type
        when 'ImportSpecifier'
          meta = xyz
          break unless meta?.namespace
          namespaces.set specifier.local.name, meta.namespace
    '''
  )

  transformed(
    '''
      switch (a) {
        case b:
          while (true) {
            break
          }
      }
    '''
    '''
      switch a
        when b
          while yes
            break
    '''
  )

describe 'fallthrough', ->
  test 'duplicates simple fallthrough block', ->
    transformed(
      '''
        switch (a) {
          case 'b': {
            x = 1
          }
          case 'c': {
            x = 2
            y = 4
            break
          }
          case 'd': {
            x = 3
          }
        }
      '''
      '''
        switch a
          when 'b'
            x = 1
            x = 2
            y = 4
          when 'c'
            x = 2
            y = 4
          when 'd'
            x = 3
      '''
    )

  test 'accumulates multiple fallthrough blocks', ->
    transformed(
      '''
        switch (a) {
          case 'b': {
            x = 1
          }
          case 'c': {
            x = 2
            y = 4
          }
          case 'd': {
            x = 3
          }
        }
      '''
      '''
        switch a
          when 'b'
            x = 1
            x = 2
            y = 4
            x = 3
          when 'c'
            x = 2
            y = 4
            x = 3
          when 'd'
            x = 3
      '''
    )

  test "doesn't duplicate after break", ->
    transformed(
      '''
        switch (a) {
          case 'b': {
            x = 1
            break
          }
          case 'c': {
            x = 2
            y = 4
          }
        }
      '''
      '''
        switch a
          when 'b'
            x = 1
          when 'c'
            x = 2
            y = 4
      '''
    )

  test "doesn't duplicate after return", ->
    transformed(
      '''
        function b() {
          switch (a) {
            case 'b': {
              x = 1
              return
            }
            case 'c': {
              x = 2
              y = 4
            }
          }
        }
      '''
      '''
        b = ->
          switch a
            when 'b'
              x = 1
              return
            when 'c'
              x = 2
              y = 4
      '''
    )

  test 'duplicates default case', ->
    transformed(
      '''
        switch (a) {
          case 'b': {
            x = 1
          }
          default: {
            x = 2
          }
        }
      '''
      '''
        switch a
          when 'b'
            x = 1
            x = 2
          else
            x = 2
      '''
    )

  test 'duplicates with empty cases', ->
    transformed(
      '''
        switch (a) {
          case 'a':
          case 'b':
            x = 1
          case 'c':
          case 'd':
            x = 2
        }
      '''
      '''
        switch a
          when 'a', 'b'
            x = 1
            x = 2
          when 'c', 'd'
            x = 2
      '''
    )
