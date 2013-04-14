fs = require 'fs'
fs.path = require 'path'
os = require 'os'
_ = require 'underscore'
async = require 'async'
crush = require './crush'

class exports.Bundle
    constructor: (@source, options = {}) ->
        # processes that depend on certain files already having been processed
        # can wait for those files -- they're put in the `watchers` queue
        @cache = {}
        @watchers = {}

        ###
        compression options: 
        0     leave it to my file server
        1     compress and add .gz to HTML
        2     compress but don't change the extension (AWS S3 compatibility)
        ###
        @options = _.defaults options, 
            entrypoints: []
            environment: 'production'
            compress: 0
            inline: no
            stream: yes


    processEntryPoints: (callback) ->
        # TEMPORARY BYPASS
        return callback null

        # TODO: process any entry points first to get a better idea
        # of what JavaScript, CSS etc. is out there so we can 
        # better optimize the whole project
        async.map @entrypoints, (file, done) -> 
            file.load -> file.findLinks yes, done

        # directives are (url, bundle, location, compilerType) tuples
        @directives = {}

        callback null

        # REFACTOR: this logic belongs in processEntryPoints (in a different form)
        # 
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


    processFiles: (callback) ->
        # see worker.coffee for potential clustering options

        ###
        Will probably have to replace this with a proper async.cargo
        because I think what's happening is that async.until is
        getting all the attention and the work is not.

        q.drain ->
            if loaded then callback null
        ###

        loaded = no
        process = (file, done) -> file.process done

        cargo = async.cargo (files, done) -> 
            async.each files, process, done
        cargo.drain = -> if loaded then callback null

        @source.each (file) -> cargo.push file
        @source.end -> loaded = yes

    generate: (callback, @verbose = no) ->
        @processEntryPoints =>
            @processFiles callback

    get: (path, callback) ->
        if @cache[path]?
            callback @cache[path].content
        else
            watchers = @watchers[path] ?= []
            watchers.push(callback)

    add: (file) ->
        # this will be called like `File#bundle.add this` when the file has been
        # processed

        # cache all .js and .css that passes by
        # (so other files can inline it)
        if @options.inline and file.extension in ['.js', '.css']
            @cache[file.path] = file

        # NOTICE: make sure that `path` is always output path!
        while @watchers[file.path].length
            callback = @watchers.shift()
            # TODO: evaluate later whether passing the entire `file`
            # object makes more sense (I'm thinking not.)
            callback file.content

        # streaming (writing to the file system ASAP)
        # is faster and much more memory-efficient
        if @options.stream
            @files.push file.metadata()
            file.save()
        else
            @files.push file

        # TODO 
        # (`add` can report stats on every generated file -- when verbose --
        # but regardless of whether it does, it's in charge of tallying
        # up the final stats.)
        if @verbose then file.report console.log

    report: ->
        ###
        Final report with aggregates.

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