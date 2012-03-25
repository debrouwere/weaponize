jsdom = require 'jsdom'
{parser, uglify} = require 'uglify-js'
csso = require 'csso'
fs = require 'fs'
fs.path = require 'path'

exports.jQueryPath = jquery = fs.path.join __dirname, '../vendor/jquery/1.7.1/jquery.min.js'

exports.html =
    run: (uri, callback) ->
        # TODO: actually run *all* JavaScript
        jsdom.jsdom uri, [jquery], callback

    parse: (uri, callback) ->
        jsdom.env uri, [jquery], callback
    
exports.code =
    compress: (code) ->
        uglify.gen_code uglify.ast_squeeze uglify.ast_mangle parser.parse code

    wrapInClosure: (code) ->
        """
        (function(){
            #{code}
        })(this);
        """

exports.styles =
    compress: (code) ->
        code = csso.justDoIt code
        # don't know why csso creates this global, but it does in 1.2.13
        delete global['v']
        code
