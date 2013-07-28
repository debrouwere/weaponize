fs = require 'fs'
fs.path = require 'path'
findit = require 'findit'
wrench = require 'wrench'
crush = require './crush'

###
Directory and Buffer serve to make it easy to generate a bundle from either 
an existing bunch of files or from content in memory. The latter is useful
for content generators that want to hook into Pagecrush directly to 
write an optimized bundle to the filesystem.
###

class exports.IO

class exports.Directory extends exports.IO
    constructor: (@root, @exclude=['.']) ->
        # TODO ...
        @directives = {}

    includes: (path) ->
        _.any @exclude, (exclude) -> (path.indexOf exclude) isnt 0

    # consumption
    each: (callback) ->
        # process.nextTick

        # we initialize as close as possible to defining our callback 
        # so `findit` doesn't start searching before we've had a chance
        # to define our callback
        @finder ?= findit.find @root

        @finder.on 'file', (path, stat) =>
            if @includes path then callback path, null

    end: (callback) ->
        @finder.on 'end', callback

    # persistence
    write: (file, callback) ->
        path = fs.path.join @root, file.path
        console.log 'writing to ' + path
        dir = fs.path.dirname path
        wrench.mkdirSyncRecursive dir
        
        # TODO: allow people to determine whether or not to add .gz
        # (useful for AWS S3)
        if file.gzippedContent
            fs.writeFile (path + '.gz'), file.gzippedContent, callback
        else if file.content
            fs.writeFile path, file.content, 'utf8', callback
        else
            src = fs.createReadStream file.metadata.original.path
            dest = fs.createWriteStream path
            src.pipe dest
            dest.on 'end', callback

normalize = (file...) ->
    #console.log file
    if file[0] instanceof crush.File
        file[0]
    else
        new crush.File file...

class exports.Buffer extends exports.IO
    constructor: ->
        @files = []

    # consumption
    each: (callback) ->
        process.nextTick =>
            for file in @files
                callback file
            @callback null

    # `end` specifies the drain callback, but it's 
    # `close` that will actually execute it
    end: (@callback) ->

    # creation
    # TODO: normalize
    add: (file...) ->
        file = normalize file...
        # console.log 'adding file ', file.path, file.content
        @files.push file

    # for consistency with io.Directory
    write: (file..., callback) ->
        @add file...
        callback null
    
    close: ->
        process.nextTick =>
            @callback()

    # expose
    serve: ->
        'TODO: SERVE @files WITH EXPRESS.JS'