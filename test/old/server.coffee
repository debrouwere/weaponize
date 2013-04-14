railgun = require '../src'

example = __dirname + '/examples/basic/index.html'

###
railgun.createServer example, (server) ->
    server.listen 4000
###
