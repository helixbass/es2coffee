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
      while yes then break
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
          while yes then break
    '''
  )
