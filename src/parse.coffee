utils = require './utils'


class Link
    initialize: (el) ->
        @el = $ el
        @type = @el.nodeName
        @src = @el.attr 'src'
        @href = @el.attr 'href'
        @rel = @el.attr 'rel'
        @ignore = (@el.data 'weaponize-ignore')?
        @precompile = (@el.data 'precompile')?
        @path = @src or @href
        @normalizedPath = utils.url.declutter @path

        @isAbsolutePath = @path.indexOf('/') is 0
        @isRemote = @path.indexOf('http') is 0
        @isInternal = @el.hasClass('jsdom')              

        if @el.parents('head').length
            @location = 'head'
        else
            @location = 'body'

        if @isRemote
            @filename = no
        else
            @filename = utils.url.path @path
