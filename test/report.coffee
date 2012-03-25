should = require 'should'
railgun = require '../src'
fs = require 'fs'
fs.path = require 'path'
wrench = require 'wrench'

example = __dirname + '/examples/advanced/index.html'
destination = __dirname + '/tmp'

it 'can write that bundle to an output dir', (done) ->
    if fs.path.existsSync destination
        wrench.rmdirSyncRecursive destination

    railgun.bundle example, (errors, bundle) ->
        railgun.package bundle, destination, (errors) ->
            console.log bundle.report()
            done()
