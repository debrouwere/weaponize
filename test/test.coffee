should = require 'should'
railgun = require '../src'
fs = require 'fs'
fs.path = require 'path'
wrench = require 'wrench'

example = __dirname + '/examples/advanced/index.html'
destination = __dirname + '/tmp'

it 'can concatenate JavaScript files in an HTML document and return a new, bundled application', (done) ->
    railgun.bundle example, (errors, bundle) ->
        #console.log JSON.stringify bundle, undefined, 4
        done()

it 'can write that bundle to an output dir', (done) ->
    if fs.path.existsSync destination
        wrench.rmdirSyncRecursive destination

    railgun.bundle example, (errors, bundle) ->
        railgun.package bundle, destination, (errors) ->
            console.log errors
            console.log 'done'
            done()
