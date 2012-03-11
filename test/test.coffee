should = require 'should'
railgun = require '../src'

example = __dirname + '/examples/advanced/index.html'

it 'can concatenate JavaScript files in an HTML document and return a new, bundled application', (done) ->
    railgun.bundle example, (errors, bundle) ->
        console.log JSON.stringify bundle, undefined, 4
        done()

it 'can write that bundle to an output dir', ->
    #railgun.package example
