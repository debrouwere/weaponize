###
If I wanted to speed this up more, I'd need something
roughly like this...
###

id = 0
cpus = 8
queue = [] # FIFO queue
pending = {}

# this would belong in bundle.coffee, of course, not in worker.coffee
cluster = require 'cluster'
cluster.setupMaster exec: 'worker.coffee'
workers = (cluster.fork() for i in [1..cpus])

if cluster.isMaster
    @source.each (path, content) =>
        if @includes path
            # we can't push objects containing methods
            # etc. across the wire
            queue.push [id, [path, content, {options: bundle.options}]]
            id++
    @source.closed ->
        loaded = yes

    worker = (done) ->
        parameters = queue.shift()
        id = parameters[0]
        proc = cluster.workers[id % cpus]
        proc.send parameters
        pending[id] = done

    dispatch = (done) ->
        async.until _.empty(queue), worker, done

    finish = ->
        _.empty(queue) and _.empty(pending) and loaded

    async.until finish, dispatch, ->
        worker.disconnect() for worker in workers
        callback()

if cluster.isWorker
    process.on 'message', (parameters) ->
        id = parameters.shift()
        file = new File parameters...

        file.process ->
            master.send id
else
    process.on 'message', (done) ->
        done()            

###
Note that this is really the sort of thing that should be benchmarked, 
because it's unclear whether IO will be the blocking factor or whether
having more CPU cycles at our disposal will actually help (jsdom etc.
is not light-weight!)

[Of course in the long term I might want to replace JSDOM with a 
proper parser and HTML writer, but last time I checked they 
were all awful to work with -- jQuery and JSDOM get the job done]
###