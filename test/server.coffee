railgun = require '../src'

example = __dirname + '/example/index.html'

railgun.createServer example, (server) ->
    server.listen 4000
