# REFACTOR: this needs to disappear into the functionality above
LINKFN = 
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

    # REFACTOR: this logic belongs in processEntryPoints (in a different form)
    # (or a function called by processEntryPoints)
    #
    # Or perhaps I can keep it as part of crush.File, but just not call it
    # except for entrypoints!
    # 
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

    # REFACTOR: this logic belongs in processEntryPoints (in a different form)
    # (or a function called by processEntryPoints)
    #     
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
