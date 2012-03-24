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
_ = require 'underscore'
async = require 'async'
findit = require 'findit'
tilt = require 'tilt'
mime = require 'mime'
utils = require './utils'
envv = require 'envv'

change_extension = (file, mimetype) ->
    extlen = fs.path.extname(file).length - 1
    file.slice(0, -extlen) + mime.extension mimetype

absolutize = (path, against) ->
    return path if path.indexOf('/') is 0
    root = fs.path.dirname against
    fs.path.join root, path

get_scripts = (window, root) ->
    $ = window.$
    $('script')
        .map ->
            src = ($ @).attr 'src'
            path = absolutize src, root
            type = ($ @).attr 'type'
            {src, type}
        .get()
        .filter (script) ->
            script.src isnt utils.jQueryPath

get_styles = (window, root) ->
    $ = window.$
    $('link')
        .filter ->
            rel = ($ @).attr 'rel'
            rel is 'stylesheet'
        .map ->
            src = ($ @).attr 'src'
            path = absolutize src, root
            type = ($ @).attr 'type'
            {src, type}
        .get()

class Bundle
    constructor: (@entrypoint, @environment) ->
        @root = fs.path.dirname @entrypoint
        @relativeEntrypoint = @entrypoint.slice @root.length
        @files = []

    shouldInclude: (file) ->
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
            scripts = get_scripts window, @root
            scripts.forEach (script) =>
                if script.type and tilt.getHandlerByMime script.type
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
                scripts: _(get_scripts window, @root).pluck 'src'
                styles: _(get_styles window, @root).pluck 'src'
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
        links = _.compact @links.scripts.concat @links.styles

        load = (link, done) =>
            link = @find '/' + link
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
    optimize: (self..., callback) ->
        scripts = @links.scripts
            .map (ref) =>
                (@find '/' + ref).content
            .join ';\n'
        
        @push @root + '/application.min.js', 
            compilerType: 'noop'
            content: utils.code.compress scripts
            origin: @links.scripts
        @remove ('/' + script) for script in @links.scripts
        
        callback null, this

    # (7) rewrite HTML files to point to our optimized scripts and styles
    rewriteHtml: (self..., callback) ->
        entrypoint = @find @relativeEntrypoint
    
        utils.html.parse entrypoint.content, (errors, window) =>
            $ = window.$

            links = @optimizedLinks = 
                scripts: []
                links: []

            $('script').each ->
                el = $ @
                src = el.attr('src')
                # we can't remove all scripts -- absolute references to
                # external scripts and styles should be kept intact
                relative = src.indexOf('/') isnt 0
                internal = src.indexOf('http') isnt 0
                util = el.hasClass('jsdom')
                
                if util or relative or internal
                    el.remove()
                else
                    links.scripts.push src    
                
            script = window.document.createElement('script')
            script.type = 'text/javascript'
            script.src = 'application.min.js'
            window.document.getElementsByTagName('head')[0].appendChild script
            links.scripts.push script.src

            entrypoint.content = window.document.outerHTML
            
            callback null, this        

    report: ->

exports.bundle = (args..., callback) ->
    [entrypoint, environment] = args
    environment ?= 'production'

    bundle = new Bundle entrypoint, environment
    tasks = [
        bundle.create
        bundle.preprocess
        bundle.setEnvironment
        bundle.findLinks
        bundle.aggregateLinks
        bundle.loadLinks
        bundle.optimize
        bundle.rewriteHtml
        ]
    tasks = tasks.map (task) -> _.bind task, bundle
    
    async.waterfall tasks, callback
