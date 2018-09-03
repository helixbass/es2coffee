{transformed} = require '../test_helper'

test 'correctly escapes double quotes inside TemplateLiteral', ->
  transformed '`""`', '"\\"\\""'

test 'turns multiline template literal into heredoc', ->
  transformed(
    '''
    `
      f = ->
        c
    `
  '''
    '''
    """
      f = ->
        c
    """
  '''
  )
