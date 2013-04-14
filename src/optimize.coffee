fs = require 'fs'
fs.path = require 'path'
csso = require 'csso'
{parser, uglify} = require 'uglify-js'

exports.code = 
    compress: (code) ->
        uglify.gen_code uglify.ast_squeeze uglify.ast_mangle parser.parse code


exports.styles =
    compress: (code) ->
        code = csso.justDoIt code
        # don't know why csso creates this global, but it does in 1.2.13
        delete global['v']
        code


exports.optimize = (file) ->
    # calls styles.compress, code.compress, pngcrush, a HTML compressor, 
    # whatever depending on filetype

exports.links = 
    concatenate: ->

    # Given a bunch of CSS and JS links and a bundle manifest (the origins 
    # and destinations of optimized links), produce a file manifest with a 
    # smaller but functionally equivalent list of JS and CSS references.
    # 
    # As a concrete example: if elsewhere in the process we've concatenated
    # a.js and b.js into application.min.js, and the particular page we're 
    # processing right now references a.js, b.js and c.js, our comparison 
    # will show that we can optimize those references to application.min.js 
    # and c.js.
    compare: (links, manifest) ->
        head: [link]
        body: []

        ###
        if we've bundled x.js and z.js into application.min.js, 
        but this particular file specifies x.js y.js z.js, 
        we can't replace that with application.min.js y.js
        without changing the execution order, and these 
        kinds of inefficiencies should be spotted and 
        mentioned to the user
        ###
        inefficiencies = 'link sequences that have gotten out of order'

        [{head, body}, inefficiencies]

    correct: (links, manifest) ->
        # TODO: change files that were preprocessed
        # to their proper file extension (so e.g. .coffee ==> .js)
        # Use the manifest to know about any special cases
        # (E.g. x.jade will be precompiled instead of compiled, so
        # it needs a )

    references: (links, manifest) ->
        [links, inefficiencies] = exports.links.compare links, manifest
        head = links.head.map (link) -> link.toNode()
        body = links.body.map (link) -> link.toNode()

        {head, body}
