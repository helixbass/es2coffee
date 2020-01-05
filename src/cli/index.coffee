### eslint-disable no-console ###

fs = require 'fs'
path = require 'path'
parseOpts = require 'minimist'
{endsWith} = require 'lodash'

{transform} = require '../..'

isJs = (file) -> /\.jsx?$/.test file

opts = null
sources = []
notSources = []

printLine = (line) -> process.stdout.write "#{line}\n"
printWarn = (line) -> process.stderr.write "#{line}\n"

# eslint-disable-next-line coffee/no-unused-vars
mkdirp = (dir, callback) ->
  mode = 0o777 & ~process.umask()

  # eslint-disable-next-line coffee/no-shadow
  do mkdirs = (p = dir, callback) ->
    fs.exists p, (itExists) ->
      if itExists
        callback()
      else
        mkdirs path.dirname(p), ->
          fs.mkdir p, mode, (err) ->
            return callback err if err
            callback()

writeCoffee = ({coffeePath, compiled}) ->
  coffeeDir = path.dirname coffeePath
  writeFile = ->
    fs.writeFile coffeePath, compiled, (err) ->
      if err
        printLine err.message
        process.exit 1
  fs.exists coffeeDir, (itExists) ->
    if itExists then writeFile() else mkdirp coffeeDir, writeFile

outputPath = (source, base) ->
  basename = path.parse(source).name
  srcDir = path.dirname source
  dir = unless opts.outputPath
    srcDir
  else if source is base
    opts.outputPath
  else
    path.join opts.outputPath, path.relative base, srcDir
  path.join dir, "#{basename}.coffee"

compileScript = ({source, code, base}) ->
  try
    compiled = transform code

    if opts.output?
      writeCoffee {
        compiled
        coffeePath: if opts.outputFilename and sources.length is 1
          path.join opts.outputPath, opts.outputFilename
        else
          outputPath source, base
      }
    else
      process.stdout.write compiled
  catch err
    message = err?.stack or "#{err}"
    printWarn message
    process.exit 1

compilePath = ({source, topLevel, base}) ->
  return if source in sources

  stats = null
  try
    stats = fs.statSync source
  catch err
    if err.code is 'NOENT'
      console.error "File not found: #{source}"
      process.exit 1
    throw err
  if stats.isDirectory()
    if path.basename(source) is 'node_modules'
      notSources[source] = yes
      return
    files = null
    try
      files = fs.readdirSync source
    catch readErr
      return if readErr.code is 'NOENT'
      throw err
    for file in files
      compilePath {
        source: path.join source, file
        topLevel: no
        base
      }
  else if topLevel or isJs source
    sources.push source
    delete notSources[source]
    code = null
    try
      code = fs.readFileSync source, 'utf8'
    catch readErr
      return if readErr.code is 'NOENT'
      throw readErr
    compileScript {
      source
      code: code.toString()
      base
    }
  else
    notSources[source] = yes

run = ->
  opts = parseOpts process.argv[2..]
  opts.output ?= opts.o
  if opts.output?
    outputBasename = path.basename opts.output
    if (
      '.' in outputBasename and
      outputBasename not in ['.', '..'] and
      not endsWith opts.output, path.sep
    )
      opts.outputFilename = outputBasename
      opts.outputPath = path.resolve path.dirname opts.output
    else
      opts.outputFilename = null
      opts.outputPath = path.resolve opts.output
  {_: inputPaths} = opts
  for inputPath in inputPaths
    inputPath = path.resolve inputPath
    compilePath
      source: inputPath
      topLevel: yes
      base: inputPath

module.exports = {run}
