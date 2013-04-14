should = require 'should'
weaponize = require '../src'
fs = require 'fs'
fs.path = require 'path'

# example = __dirname + '/examples/advanced/index.html'
# destination = __dirname + '/tmp'

it 'can inline CSS and JavaScript (useful for single-page apps)', (done) ->