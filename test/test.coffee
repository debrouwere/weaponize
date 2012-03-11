should = require 'should'
railgun = require '../src'

example = __dirname + '/example/index.html'

it 'can concatenate JavaScript files in an HTML document and return a new, bundled application', (done) ->
    railgun.bundle example, (errors, bundle) ->
        console.log bundle
        done()

it 'can write that bundle to an output dir', ->
    #railgun.package example
