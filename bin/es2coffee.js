#!/usr/bin/env node

'use strict'

var path = require('path');
var fs = require('fs');

var potentialPaths = [
  path.join(process.cwd(), 'node_modules/es2coffee/lib'),
  path.join(__dirname, '../lib')
]

for (var i = 0; i < potentialPaths.length; i++) {
  if (fs.existsSync(potentialPaths[i])) {
    require(potentialPaths[i] + '/cli').run()
  }
}
