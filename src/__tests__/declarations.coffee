{transformed} = require '../test_helper'

test 'correctly handles non-initialized declaration', ->
  transformed 'let a', 'a = undefined'

  transformed 'var a', 'a = undefined'

  transformed 'var a, b = 1', '''
    a = undefined
    b = 1
  '''
