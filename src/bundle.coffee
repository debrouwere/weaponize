utils = require './utils'
fs = require 'fs'
fs.path = require 'path'
async = require 'async'

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
            {path, type}
        .get()
        .filter (script) ->
            script.path isnt utils.jQueryPath

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
            {path, type}
        .get()

# applications can have all sorts of resources that are not referenced in the app 
# entrypoint (viz. the index.html) -- so we need to find *all* files in the project
# directory and return all of those that we won't already process in our optimization
# pipeline
get_resources = (root, exclude) ->

fs.readFileUTF8 = (file, callback) ->
    fs.readFile file, 'utf8', callback

load = (files, callback) ->
    async.map files, fs.readFileUTF8, callback

exports.bundle = (entrypoint, callback) ->
    utils.html.parse entrypoint, (errors, window) ->
        $ = window.$
        scripts = get_scripts window, entrypoint
        styles = get_styles window, entrypoint

        scripts = scripts.map (script) -> script.path
        load scripts, (errors, scripts) ->
            scripts = scripts
                .map (script) ->
                    utils.code.compress script
                .join(';\n')

            $('script').remove()
            script = window.document.createElement("script")
            script.type = 'text/javascript'
            script.src = 'application.min.js'
            window.document.getElementsByTagName('head')[0].appendChild script
            $('h1').text 'An optimized Hello World, just for you'

            # TODO: we need to have the code build up this hash
            callback null, {
                "index.html": window.document.outerHTML
                "application.min.js": scripts
                }
