{transformed} = require '../test_helper'

test 'leading * -> #', ->
  transformed(
    '''
      /*
       * comment
       *
       * yes
       */
      x()
    '''
    '''
      ###
      # comment
      #
      # yes
      ###
      x()
    '''
  )

test 'leading JSDoc * -> #', ->
  transformed(
    '''
      /**
       * comment
       *
       * yes
       */
      x()
    '''
    '''
      ###*
      # comment
      #
      # yes
      ###
      x()
    '''
  )

test "don't rewrite indented *", ->
  transformed(
    '''
      /*
        comment
        
        yes
          * something
          * else
       */
      x()
    '''
    '''
      ###
        comment

        yes
          * something
          * else
      ###
      x()
    '''
  )
