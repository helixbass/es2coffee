{transformed} = require '../test_helper'

test 'correctly transforms named export declaration', ->
  transformed(
    '''
    export const a = 1
  '''
    '''
      export a = 1
    '''
  )

test 'correctly transforms named export function declaration', ->
  transformed(
    '''
      export function testFilePath(relativePath) {
      }
    '''
    '''
      export testFilePath = (relativePath) ->
    '''
  )
