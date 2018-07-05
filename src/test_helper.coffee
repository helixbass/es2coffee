{transform} = require '..'

transformed = (js, cs) ->
  expect(transform(js).trim()).toBe cs

module.exports = {transformed}
