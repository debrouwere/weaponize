fs = require 'fs'
fs.path = require 'path'
mime = require 'mime'
zlib = require 'zlib'
_ = require 'underscore'
async = require 'async'
findit = require 'findit'
tilt = require 'tilt'
url = require 'url'
envv = require 'envv'
utils = require './utils'
parse = require './parse'
optimize = require './optimize'


# Not all tasks are relevant to all files: 
# JavaScript and CSS we'll want to optimize
# and HTML we'll want to rewrite
TASKSETS =
    __all__: [
        'load'
        'stat'
        'name'
        ]

    image: [
        'optimize'
        'write'
        ]

    script: [
        'preprocess'
        'optimize'
        'gzip'
        'write'
        ]

    style: [
        'preprocess'
        'optimize'
        'gzip'
        'write'
        ]

    html: [
        'preprocess'
        #'setEnvironment'
        #'rewriteHTML'
        #'inline'
        #'optimize'
        #'gzip'
        'write'
        ]

    plain: [
        'write'
        ]

    binary: [] # TODO

# add shared tasks to other task sets
for set of TASKSETS
    continue if set is '__all__'
    TASKSETS[set] = TASKSETS.__all__.concat TASKSETS[set]

# REFACTOR: everywhere we use certain options, 
# remember they're in @bundle.options now!
class exports.File
    constructor: (@path, @content, @bundle, @destination) ->
        ###
        compilerType determines how to preprocess a file

        - a no operation or passthrough (typically when there's a
          data-raw attribute on the link to the file)
        - a compilation step (e.g. for CoffeeScript and SASS files, will
          leave HTML, CSS and the like as-is and simply optimize it)
        - a precompilation step, used when a 'text/mylanguage' type 
          is specified (e.g. from Handlebars templates to JavaScript
          template functions)
        ###
        @mime = mime.lookup @path
        @charset = mime.charsets.lookup @mime
        @isBuffer = @content instanceof Buffer
        @isBinary = @isBuffer or @charset isnt 'UTF-8'

        @compilerType = @bundle?.directives?[@path] or 'compiler'
        
        if @compilerType is 'precompiler'
            @mimeFor = 'precompiledOutput'
        else
            @mimeFor = 'output'

        file = new tilt.File path: @path
        @handler = tilt.findHandler file
        if @handler
            @type = utils.filetype @handler.mime.output
        else
            @type = utils.filetype @mime

        # select the appropriate task pipeline for this type of file
        @tasks = TASKSETS[@type].map (task) =>
            fn = _.bind @[task], this
            fn._name = task
            fn

        ###
        * size: file size
        * links: the total number of external requests this file
          will generate (stylesheets, javascript, images)
        * operations: a list of all crush operations that were performed
          e.g. inlining, uglification, ...
        ###
        @metadata = 
            original:
                path: @path
                extension: fs.path.extname @path
                size: null
                links: null
            crushed:
                path: null
                extension: null
                size: null
                links: null
            operations: []

    # TODO: update metadata (path, size)
    load: (callback) ->
        if @content?
            callback null
        else if @isBinary
            fs.readFile @path, (err, @content) =>
                @isBuffer = yes
                callback err
        else
            fs.readFile @path, @charset, (err, @content) =>
                callback err

    stat: (callback) ->
        @metadata.original.size = @content.length
        callback null

    # TODO: eh, make this actually work
    name: (callback) ->
        if @handler
            oldExt = @metadata.original.extension
            newExt = '.' + mime.extension @handler.mime[@mimeFor]
            @path = @metadata.crushed.path = @path.replace oldExt, newExt
            @metadata.crushed.extension = newExt
        else
            @metadata.crushed.path = @path
            @metadata.crushed.extension = @metadata.original.extension

        callback null

    preprocess: (callback) ->
        if @handler?
            input = new tilt.File
                    path: @path
                    content: @content

            @handler[@compilerType] input, {}, (@content) =>
                callback null
        else
            callback null

    parseHTML: (callback) ->
        @$ = cheerio.load @content
        callback null

    setEnvironment: (callback) ->
        envv.transform @content, @environment, (errors, @content) =>
            callback null

    findLinks: (callback) ->
        unless @$? callback then new Error \
            "This file is not HTML or does not have a loaded DOM."

        links = @$("*:not(a)[src],*:not(a)[href]").map (el) -> new parse.Link el

        local = links
            .filter (link) -> 
                link.filename
            .map(link) => 
                new File link.filename, @bundle

        remote = links.filter (link) -> link.isRemote

        if process
            processLink = (link, done) -> link.process done
            async.map local, processLink, (err, local) ->
                callback null, {local, remote}
        else
            callback null, {local, remote}

    rewriteHTML: ->
        optimizableReferences = @links.filter (link) -> not link.ignore
        optimized = optimize.references optimizableReferences

        # do the actual HTML rewriting
        optimizableReferences.forEach (reference) -> reference.remove()
        $("head").append(optimized.head)
        $("body").append(optimized.head)

        #@content = window.document.outerHTML
        @content = @$.root().html()

    # optional
    inline: (callback) ->
        return (callback null, this) unless @bundle.options.inline

        # - loop through every HTML file (which hopefully is just a single file
        # as this only makes sense for single-page apps so we should @warn if not)
        # - inline application.min.js and application.min.css (if they exist)
        # - remove those files from the bundle, since they're now inlined everywhere

    # TODO: optimize HTML, CSS, JS
    optimize: (callback) ->


    # REFACTOR: this is old code and won't work as-is
    gzip: (callback) ->
        return (callback null, this) unless @bundle.options.compress

        gzip = (file, done) ->
            return done() unless fs.path.extname(file.path) in ['.html', '.js', '.css']
            # TODO: considering some files have .content preloaded and some don't, 
            # maybe abstract file.content into a lazy loader / getter-setter?
            zlib.gzip (new Buffer file.content), (errors, buffer) ->
                file.gzippedContent = buffer
                done()

        async.forEach @files, gzip, (errors) =>
            callback null, this

    write: (callback) ->
        # destination can be a directory (to write to file) or it can be
        # a buffer (which we can then serve with express.js)
        @destination.write this, callback

    process: (callback) ->
        # TODO: first thing we should get working is 
        # a system that simply spits out exactly 
        # what it received without any optimizations, 
        # compilations or whatever

        # add some debugging
        tasks = @tasks.map (task) ->
            ->
                console.log '--- ' + task._name
                task arguments...

        async.series tasks, callback