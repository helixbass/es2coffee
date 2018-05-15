fs = require 'fs'
{transform} = require '../..'

run = ([inputFilename]) ->
  input = fs.readFileSync inputFilename, 'utf8'
  output = transform input
  process.stdout.write output

module.exports = {run}
