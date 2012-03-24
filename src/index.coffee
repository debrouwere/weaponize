fs = require 'fs'
fs.path = require 'path'
express = require 'express'
mime = require 'mime'
async = require 'async'
wrench = require 'wrench'

exports.bundle = require('./bundle').bundle

# `package` writes the bundle away to a directory
exports.package = (bundle, destination, callback) ->
    writeFile = (file, done) ->
        path = fs.path.join destination, file.path
        dir = fs.path.dirname path
        wrench.mkdirSyncRecursive dir
        
        if file.content
            fs.writeFile path, file.content, 'utf8', done
        else
            fs.readFile file.absolutePath, (errors, data) ->
                fs.writeFile path, data, done
        
    async.forEach bundle.files, writeFile, callback

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
