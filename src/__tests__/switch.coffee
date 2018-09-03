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

  # TODO: support this
  # transformed(
  #   '''
  #   switch (a) {
  #     case b:
  #       while (true) {
  #         break
  #       }
  #   }
  # '''
  #   '''
  #   switch a
  #     when b
  #       while yes then break
  # '''
  # )
