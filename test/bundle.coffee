should = require 'should'
weaponize = require '../src'
wrench = require 'wrench'
fs = require 'fs'
fs.path = require 'path'

# example = __dirname + '/examples/advanced/index.html'
# destination = __dirname + '/tmp'

describe 'Bundle', ->
    beforeEach ->
        if (fs.existsSync './test/tmp') then wrench.rmdirSyncRecursive './test/tmp'
        @destinationPath = './test/tmp'
        @src = new weaponize.Buffer()
        @dest = new weaponize.Directory @destinationPath
        @bundle = new weaponize.Bundle @src

    it 'can determine what to do with various file types', ->
        # TODO: add some more dummy files
        types = [
            ['index.txt', 'plain']
            ['im.png', 'image']
            ['proj.styl', 'style']
            ['code.coffee', 'script']
            ['index.jade', 'html']
        ]

        for [path, type] in types
            file = new weaponize.File path
            file.type.should.equal type

    it 'can take some buffers and write them to a directory', (done) ->
        file = new weaponize.File 'index.txt', 'Hello world!', @bundle, @dest
        file.write (err) =>
            (fs.existsSync @destinationPath + '/index.txt').should.be.true
            done err

    it 'can process plain text files', (done) ->
        @src.add new weaponize.File 'index.txt', 'Hello world!', @bundle, @dest
        @bundle.processFiles (err) =>
            (fs.existsSync @destinationPath + '/index.txt').should.be.true
            done err

    it 'can process plain HTML', (done) ->
        html = '<html><head><title>Hello world!</title></head></html>'
        @src.add new weaponize.File 'index.html', html, @bundle, @dest
        @bundle.processFiles (err) =>
            (fs.existsSync @destinationPath + '/index.html').should.be.true
            done err

    it 'can process HTML template languages', (done) ->
        tpl = """
            html
                head
                    title Hello jade!
                body
            """
        file = new weaponize.File 'index.jade', tpl, @bundle, @dest

        @src.add file
        @bundle.processFiles (err) =>
            file.metadata.crushed.extension.should.eql '.html'
            path = @destinationPath + '/index.html'
            (fs.existsSync path).should.be.true
            content = fs.readFileSync path, 'utf8'
            (content.indexOf '<html>').should.eql 0
            done err

    it 'can process images'

    it 'can process style sheets'

    it 'can process scripts'

    # TODO: also test hashes, io.Directory and io.Buffer as inputs
    it 'has a convenience function for packaging up a bundle in one go', (done) ->
        files = [
            ['index.txt', 'Hello world!']
            ]

        destination = new weaponize.Buffer()

        weaponize.package files, destination, ->
            destination.files[0].path.should.eql 'index.txt'
            done()

    it 'can take some files and write them to a directory'
    (done) ->

    it 'can process entrypoints and create
        optimized Javascript and CSS'
    (done) ->

    it 'can process entrypoints and create directives'
    (done) ->

    it 'can process an entire directory of 
        files and return an optimized version'
    (done) ->

    it 'can serve a bundle'
    (done) ->