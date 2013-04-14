class Bla
    test: ->
        console.log 'hello'

    tasks: [@test]

    other:
        tasks: [
            @test
            ]

x = new Bla()
console.log x.other.tasks