fs = require 'fs'
fs.path = require 'path'

exports.jQueryPath = jquery = fs.path.join __dirname, '../vendor/jquery/1.9.1/jquery.min.js'

filetypes = [
    ['image', 'image']
    ['css', 'style']
    ['javascript', 'script']
    ['html', 'html']
    ['plain', 'plain']
    ['xml', 'plain']
    ]

exports.filetype = (mime) ->
    for [chunk, type] in filetypes
        if (mime.indexOf chunk) isnt -1
            return type
    return 'binary'

exports.path =
    changeExtension: (file, mimetype) ->
        extlen = fs.path.extname(file).length - 1
        file.slice(0, -extlen) + mime.extension mimetype

    absolutize: (path, base) ->
        absolute = path[0] is '/'
        http = path.slice(0,4) is 'http'
        
        if absolute or http
            path
        else
            root = fs.path.dirname base
        fs.path.join root, path

exports.url =
    normalize: (src) ->
        path = url.parse src
        path.href.replace path.search, ''    

    # TODO: be smarter about cutting out querystrings
    # this makes sense for local files (because you're grabbing them as files!)
    # [though even then you may want them as cache busters]
    # but we shouldn't do this for HTTP resources that may return different
    # representations depending on a search query
    # 
    # How about only stripping `?raw` and `?precompile` (Draughtsman's query
    # strings) and only for links to stuff on the same domain?
    # 
    # Also: even locally, we should at least return a warning / notice
    # when we've stripped out a querystring
    declutter: (src) ->
        exports.url.normalize src

    
exports.code =
    wrapInClosure: (code) ->
        """
        (function(){
            #{code}
        })(this);
        """