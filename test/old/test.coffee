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
            done()

it 'can compress a bundle', (done) ->
    if fs.path.existsSync destination
        wrench.rmdirSyncRecursive destination

    # TODO: this really would make much more sense as an options object, 
    # rather than these bare yesses and no's
    railgun.bundle example, 'production', no, yes, (errors, bundle) ->
        railgun.package bundle, destination, (errors) ->
            # TODO: properly test compression by unzipping and checking content
            done()
