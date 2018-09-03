{transformed} = require '../test_helper'

test 'correctly transforms void 0 to undefined', ->
  transformed 'void 0', 'undefined'
