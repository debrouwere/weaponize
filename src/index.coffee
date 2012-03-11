express = require 'express'
mime = require 'mime'

exports.bundle = require('./bundle').bundle

# `package` writes the bundle away to a directory
exports.package = null

# `createServer` keeps the bundle in memory and serves it
exports.createServer = (entrypoint, callback) ->
    app = express.createServer()
    exports.bundle entrypoint, (errors, bundle) ->
        app.get '*', (req, res) ->
            path = req.path.slice 1
            if bundle[path]?
                res.contentType mime.lookup path
                res.send bundle[path]
            else
                res.send 404

        callback app
