{transformed} = require '../test_helper'

test 'preserves getter + setter pair', ->
  transformed(
    '''
      class A {
        get b() {
          return this._b;
        }

        set b(val) {
          this._b = val;
        }
      }
    '''
    '''
      class A
        Object.defineProperty(
          @::
          'b'
          get: -> @_b

          set: (val) ->
            @_b = val
        )
    '''
  )

test 'preserves just getter', ->
  transformed(
    '''
      const X = class {
        get b() {
          return 4;
        }
      }
    '''
    '''
      X = class
        Object.defineProperty(
          @::
          'b'
          get: -> 4
        )
    '''
  )

test 'preserves just setter', ->
  transformed(
    '''
      class A extends B {
        set b(val) {
          this._b = val;
        }
      }
    '''
    '''
      class A extends B
        Object.defineProperty(
          @::
          'b'
          set: (val) ->
            @_b = val
        )
    '''
  )
