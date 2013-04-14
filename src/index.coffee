fs = require 'fs'
fs.path = require 'path'
express = require 'express'
mime = require 'mime'
async = require 'async'
wrench = require 'wrench'
_ = require 'underscore'

_.extend exports, require './io'
_.extend exports, require './crush'
_.extend exports, require './bundle'

# `package` writes the bundle away to a directory
exports.package = (source, destination, callback = ->) ->
    bundle = new exports.Bundle()

    if typeof destination is 'string'
        destination = new exports.Directory destination

    if source instanceof exports.IO
        bundle.source = source
    else if typeof source is 'string'
        bundle.source = new exports.Directory source
    else if source.length?
        bundle.source = buffer = new exports.Buffer()
        bundle.source = buffer
        for [path, content] in source
            file = new exports.File path, content, bundle, destination
            buffer.add file
        buffer.close()
    else if typeof source is 'object'
        bundle.source = buffer = new exports.Buffer()
        for path, content of source
            file = new exports.File path, content, bundle, destination
            buffer.add file
        buffer.close()
    else
        throw new Error """`source` should be a Buffer, Directory, 
            (path, content) tuples or a path:content hash map."""

    bundle.generate callback


exports.serve = (source, callback = ->) ->
    destination = new exports.Buffer()
    exports.package source, destination, ->
        throw new Error "Not implemented yet."
        # based on the content now in `destination.files`
        # we can start an express.js static file server


###
# REFACTOR: out of date

# Keeps the bundle in middleware and serves it (this is a Connect middleware)
exports.static = (bundle) ->
    files = {}

    for file in bundle.files
        files[file.path] = 
            contentType: mime.lookup file.path
            content: file.content
            absolutePath: file.absolutePath

    (req, res, next) ->
        file = files[req.url]
        return next() unless file?
    
        res.contentType file.contentType
        if file.content?
            res.send file.content
        else
            res.sendfile file.absolutePath

exports.createServer = (entrypoint, callback) ->
    app = express.createServer()
    exports.bundle entrypoint, (errors, bundle) ->
        app.use exports.static bundle
        callback app
###