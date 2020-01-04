{transformed} = require '../test_helper'

describe "doesn't inline blocks", ->
  it "doesn't inline catch body", ->
    transformed(
      '''
        const x = () => {
          try {
            y()
          } catch (err) {
            return no
          }
          return z()
        }
      '''
      '''
        x = ->
          try
            y()
          catch err
            return no
          z()
      '''
    )
