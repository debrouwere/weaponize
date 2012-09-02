###
1. create an unoptimized bundle (walk the file tree and put paths in a hash, with path and origpath keys)
2. figure out which templates need precompilation vs. compilation and add that metadata to the bundle
   (precompilation if referenced in a file with a text/mytemplateengine type)
   (breadth-first, template by template, because files other than the index
   can also reference templates to be precompiled)
   (So it makes sense to put templates that need only precompilation inside of a `templates` dir
   so as not to confuse Railgun. As always, if Railgun is confused or is encountering compilation
   errors by trying to compile templates without the necessary context, it should spit out useful errors
   or tell people about the compilation error and ask "Did you want to precompile this file instead? Y/n")
   (The docs should communicate that this is a bit of a chicken-and-egg thing: we need to compile
   templates to know whether they refer to other templates that need to only be *pre*compiled, so
   it's a bit of a guessing game unless you properly structure your app.)
   [TODO: see how Jade precompiles extends/includes blocks to see if those need any special treatment]
3. run envv on HTML files to remove any dev environment stuff
4. find link and script references in every file, annotate the bundle
5. find the optimal order for javascript and stylesheets, complain if we can't (because e.g. in one file
   you load jQuery before a.js and in another file you load a.js before jQuery)
6. concatenate and optimize, add the concatenated file to the bundle, remove references to the original files
   with a reference to 'application.min.js'

Provide a nice little report of what we compiled, what we precompiled and what we concatenated, warnings
(if there are warnings), reduction in filesize, reduction in amount of files, reduction in amount of
requests for the entrypoint et cetera

Serving or writing away this bundle is not a part of this code, but is taken care of elsewhere in Railgun.
###

fs = require 'fs'
fs.path = require 'path'
zlib = require 'zlib'
_ = require 'underscore'
async = require 'async'
findit = require 'findit'
tilt = require 'tilt'
mime = require 'mime'
url = require 'url'
utils = require './utils'
envv = require 'envv'

change_extension = (file, mimetype) ->
    extlen = fs.path.extname(file).length - 1
    file.slice(0, -extlen) + mime.extension mimetype

absolutize = (path, base) ->
    absolute = path[0] is '/'
    http = path.slice(0,4) is 'http'
    
    if absolute or http
        path
    else
        root = fs.path.dirname base
        fs.path.join root, path

# TODO: be smarter about cutting out search queries
# this makes sense for local files (because you're grabbing them as files!)
# but we shouldn't do this for HTTP resources that may return different
# representations depending on a search query
# Also: even locally, we should at least return a warning / notice
# when we've stripped out a querystring
normalize = (src) ->
    path = url.parse src
    path.href.replace path.search, ''    

getScripts = (window, root) ->
    $ = window.$
    $('script')
        .map ->
            src = ($ @).attr 'src'
            # strip out querystring, if any, and turn
            # into an absolute path
            src = normalize src
            # path = absolutize src, root
            type = ($ @).attr 'type'
            precompile = ($ @).data 'precompile'
            {src, type, precompile}
        .get()
        .filter (script) ->
            script.src isnt utils.jQueryPath

getStyles = (window, root) ->
    $ = window.$
    $('link')
        .filter ->
            rel = ($ @).attr 'rel'
            rel is 'stylesheet'
        .map ->
            src = ($ @).attr 'href'
            src = normalize src
            # path = absolutize src, root
            type = ($ @).attr 'type'
            {src, type}
        .get()

class exports.Bundle
    constructor: (@entrypoint, @environment, @inline = no, @compress = no, @exclude = []) ->
        @root = fs.path.dirname @entrypoint
        @relativeEntrypoint = @entrypoint.slice @root.length
        @files = []

    shouldInclude: (file) ->
        # TODO: exclude everything starting with @exclude
        # _.any @exclude, (exclude) -> (file.indexOf exclude) is 0
        name = fs.path.basename file
        hidden = name.indexOf('.') is 0
        not hidden

    # TODO: merge options against a default
    push: (path, options) ->
        # the bundle works with relative paths
        relpath = path.slice @root.length
        defaults =
            path: relpath
            originalPath: relpath
            absolutePath: path
            # undefined, noop, compiler or precompiler
            compilerType: 'compiler'
            operations: []

        @files.push _.extend defaults, options


    remove: (path) ->
        for file, i in @files
            if path in [file.path, file.originalPath]
                return @files.splice i, 1

    find: (path) ->
        _.find @files, (file) -> path in [file.path, file.originalPath]

    # (1) create an unoptimized bundle
    create: (callback) ->
        finder = findit.find @root
        finder.on 'file', (file) =>
            if @shouldInclude file
                @push file
        finder.on 'end', =>
            callback null, this

    # anything referred to in a script tag with a a text/<templatelanguage> type
    # should be precompiled, not compiled (except script languages?)
    # -- perhaps we should make this explicit, or is that unnecessary?
    # or just assume that precompilation should work for e.g. text/coffeescript too, 
    # but check if it has a precompiler and revert to regular compilation instead
    # if it doesn't (& inform the user of this process when they see a template context related
    # error)
    updateMetadata: (bundlefile, callback) ->
        utils.html.parse bundlefile.content, (errors, window) =>
            $ = window.$
            scripts = getScripts window, @root
            scripts.forEach (script) =>
                if script.precompile
                    s = @find '/' + script.src
                    s.compilerType = 'precompiler'                   

            callback()

    preprocessFile: (bundlefile, callback) ->
        # callback null, this if bundlefile.operations > 0
        file = new tilt.File path: bundlefile.absolutePath
        handler = tilt.findHandler file

        if handler?
            file.load =>
                handler[bundlefile.compilerType] file, {}, (output) =>
                    if bundlefile.compilerType is 'precompiler'
                        mimetype = handler.mime.precompiledOutput
                    else
                        mimetype = handler.mime.output
                    bundlefile.path = change_extension bundlefile.path, mimetype
                    bundlefile.content = output
                    # update metadata
                    if handler.mime.output is 'text/html'
                        @updateMetadata bundlefile, =>
                            callback null, this
                    else
                        callback null, this
        else
            bundlefile.compilerType = 'noop'
            # TODO: refactor
            # update metadata
            if (fs.path.extname bundlefile.path) is '.html'
                file.load =>
                    bundlefile.content = file.content
                    @updateMetadata bundlefile, =>
                        callback null, this
            else
                callback null, this

    # (2)
    preprocess: (self..., callback) ->
        # preprocess files one by one
        # - skipping them if they've already been compiled (operations.length > 0)
        # - precompiling or compiling depending on file.compilationType, and adding the compiled result to file.content
        # - changing `path` with the preferred new extension
        # - annotate file.operations
        # - for HTML, read through the file for script references, and then annotate
        #   those referenced files as files that need precompilation instead of compilation
        #   (if the type indicates precompilation instead of compilation, e.g. text/jade)
        entrypoint = @find @relativeEntrypoint
        preprocessFile = _.bind @preprocessFile, this
        # preprocess the entry point first
        preprocessFile entrypoint, =>
            # preprocess everything else, but one file at a time
            async.mapSeries @files, preprocessFile, (errors, results) =>
                callback null, this

    # (3) run each html file through envv at this point to get rid of dev-only code
    setEnvironment: (self..., callback) ->
        environment = @environment
    
        htmlFiles = @files.filter (file) ->
            file.path.slice(-4) is 'html'

        applyEnvironment = (file, done) ->
            envv.transform file.content, environment, (errors, html) ->
                file.content = html
                done()
    
        async.forEach htmlFiles, applyEnvironment, (errors) =>
            callback null, this

    findLinksInFile: (bundlefile, callback) ->
        return callback() unless (fs.path.extname bundlefile.path) is '.html'
        
        utils.html.parse bundlefile.content, (errors, window) =>
            $ = window.$
            bundlefile.links =
                scripts: _(getScripts window, @root).pluck 'src'
                styles: _(getStyles window, @root).pluck 'src'
            callback()

    # (4) find all script and link tags and annotate the bundle
    findLinks: (self..., callback) ->
        findLinksInFile = _.bind @findLinksInFile, this
    
        async.forEach @files, findLinksInFile, (errors) =>
            callback null, this

    # (5) try to merge and order links from all the different files
    # in a logical way
    aggregateLinks: (self..., callback) ->
        # TODO: do we want to support smart (re)ordering or not?
        links = _(@files)
            .chain()
            .pluck('links')
            .filter (links) ->
                links?
            .reduce ((a, b) ->
                a.scripts.push b.scripts...
                a.styles.push b.styles...
                a
                ), {scripts: [], styles: []}

        @links = links.value()
        
        callback null, this

    loadLinks: (self..., callback) ->
        # _.compact 
        links = @links.scripts.concat @links.styles

        load = (link, done) =>
            return done() if link.slice(0,4) is 'http'
                
            link = @find '/' + link
            return done(new Error "File not found: #{link}") unless link?

            #  don't try to reload links (especially since their `content`
            # may already contain a precompiled version rather than raw
            # file contents)
            return done() if link.content
            
            fs.readFile link.absolutePath, 'utf8', (errors, data) ->
                link.content = data
                done()

        async.forEach links, load, (errors) =>
            callback errors, this

    # (6) concatenate and optimize scripts and stylesheets
    optimizeStyles: (self..., callback) ->
        if @links.styles.length
            optimizableStyles = @links.styles
                .filter (ref) ->
                    ref.slice(0,4) isnt 'http'

            styles = optimizableStyles
                .map (ref) =>
                    file = (@find '/' + ref)
                    if file?
                        return file.content
                    else
                        return callback new Error "Optimization failed. Could not load file: #{ref}"
                    file.content
                .join '\n'

            @push @root + '/application.min.css', 
                compilerType: 'noop'
                content: utils.styles.compress styles
                origin: @links.styles
            @remove ('/' + style) for style in optimizableStyles
        
        callback null, this
    
    optimizeScripts: (self..., callback) ->
        if @links.scripts.length
            optimizableScripts = @links.scripts
                .filter (ref) ->
                    ref.slice(0,4) isnt 'http'

            scripts = optimizableScripts
                .map (ref) =>
                    file = (@find '/' + ref)
                    if file?
                        return file.content
                    else
                        return callback new Error "Optimization failed. Could not load file: #{ref}"
                    file.content
                .join ';\n'
            
            @push @root + '/application.min.js', 
                compilerType: 'noop'
                content: utils.code.compress scripts
                origin: @links.scripts
            @remove ('/' + script) for script in optimizableScripts
        
        callback null, this

    # (7) rewrite HTML files to point to our optimized scripts and styles
    rewriteHtml: (self..., callback) ->
        entrypoint = @find @relativeEntrypoint
    
        utils.html.parse entrypoint.content, (errors, window) =>
            $ = window.$

            links = @optimizedLinks = 
                scripts: []
                styles: []

            insertBefore = {}
            resources = $("script").add("link[rel='stylesheet']")
            resources.each (i) ->
                el = $ @
                type = el.get(0).nodeName.toLowerCase()
                src = el.attr('src') or el.attr('href')
                # we can't remove all scripts -- absolute references to
                # external scripts and styles should be kept intact
                relative = src.indexOf('/') isnt 0
                internal = src.indexOf('http') isnt 0
                util = el.hasClass('jsdom')
                
                if util or (relative and internal)
                    el.remove()
                    # guarantee insertion of optimizable JavaScript and CSS
                    # *before* the last unoptimizable script or link respectively
                    # (this isn't perfect)
                    next = resources.eq(i+1)
                    if next.length
                        insertBefore[type] = next
                else
                    # BUG: `push` can break scripts because it enters them out-of-order
                    # instead we need to find the first or last script/stylesheet we're
                    # replacing and enter it at that position.
                    if type is 'script'
                        links.scripts.push src
                    else
                        links.styles.push src

            head = window.document.getElementsByTagName('head')[0]

            if @links.scripts.length
                script = window.document.createElement('script')
                script.type = 'text/javascript'
                script.src = 'application.min.js'
                if insertBefore.script
                    head.insertBefore script, insertBefore.script.get(0)
                else
                    head.appendChild script
                # log
                links.scripts.push script.src

            if @links.styles.length
                link = window.document.createElement('link')
                link.rel = 'stylesheet'
                link.href = 'application.min.css'
                if insertBefore.link
                    head.insertBefore link, insertBefore.link.get(0)
                else
                    head.appendChild link
                # log
                links.styles.push link.href

            entrypoint.content = window.document.outerHTML
            
            callback null, this        

    # optional
    inline: (self..., callback) ->
        return callback(null, this) unless @inline

        # - loop through every HTML file (which hopefully is just a single file
        # as this only makes sense for single-page apps so we should @warn if not)
        # - inline application.min.js and application.min.css (if they exist)
        # - remove those files from the bundle, since they're now inlined everywhere

    # optional
    gzip: (self..., callback) ->
        return callback(null, this) unless @compress

        gzip = (file, done) ->
            return done() unless fs.path.extname(file.path) in ['.html', '.js', '.css']
            # TODO: considering some files have .content preloaded and some don't, 
            # maybe abstract file.content into a lazy loader / getter-setter?
            zlib.gzip (new Buffer file.content), (errors, buffer) ->
                file.gzippedContent = buffer
                done()

        async.forEach @files, gzip, (errors) =>
            callback null, this

    report: (self..., callback) ->
        ###
        WARNINGS
        - trying to inline but there's more than one HTML file
        - different pages include different styles or scripts, 
        which may upset the optimization process
        - we've cut away querystrings from local files that have
        been concatenated
        - couldn't find a referenced file (we don't die because 
        another non-railgun build step could conceivably add in more files)

        DIE
        - couldn't compile something
        - out-of-order Javascript insertion

        STATS (#, # original, # change, % change)
        - amount of requests rendering the front page will take (`index.html`)
        - bundle file size
        - gzipped bundle file size
        - bundle files
        - scripts replaced by CDN versions (+ CDN provider for each)
        ###
        callback null, this

exports.optimize = (bundle, callback) ->
    tasks = [
        bundle.preprocess
        bundle.setEnvironment
        bundle.findLinks
        bundle.aggregateLinks
        bundle.loadLinks
        bundle.optimizeStyles
        bundle.optimizeScripts
        bundle.rewriteHtml
        #bundle.inline
        #bundle.gzip
        #bundle.report
        ]
    tasks = tasks.map (task) -> _.bind task, bundle
    
    async.waterfall tasks, callback

exports.bundle = (args..., callback) ->
    [entrypoint, environment, inline, compress] = args
    environment ?= 'production'

    bundle = new exports.Bundle entrypoint, environment, inline, compress
    bundle.create ->
        exports.optimize bundle, callback