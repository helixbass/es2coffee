{transformed} = require '../test_helper'

test 'generates shorthand this', ->
  transformed 'this', '@'
  transformed 'this.x', '@x'
  transformed 'this[2]', '@[2]'
