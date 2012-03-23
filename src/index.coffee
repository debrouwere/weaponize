express = require 'express'
mime = require 'mime'

exports.bundle = require('./bundle').bundle

# `package` writes the bundle away to a directory
exports.package = null

# Keeps the bundle in middleware and serves it
# This is a Connect middleware
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
