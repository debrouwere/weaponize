should = require 'should'
railgun = require '../src'
fs = require 'fs'
fs.path = require 'path'
wrench = require 'wrench'

example = __dirname + '/examples/advanced/index.html'
destination = __dirname + '/tmp'

it 'can report on the optimizations it did while bundling', (done) ->
    if fs.path.existsSync destination
        wrench.rmdirSyncRecursive destination

    railgun.bundle example, (errors, bundle) ->
        console.log bundle.report()

it 'can report on the optimizations it did while packaging', (done) ->
    if fs.path.existsSync destination
        wrench.rmdirSyncRecursive destination

    railgun.bundle example, (errors, bundle) ->    
        railgun.package bundle, destination, (errors) ->
            console.log bundle.report()
            done()
