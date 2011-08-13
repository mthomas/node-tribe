http = require('http')
express = require('express')
redis = require('redis').createClient()
subs = require('redis').createClient()
async = require('async')

app = express.createServer()

io = require('socket.io').listen(app)

weather = (callback) ->
  options =
    host: 'http://www.google.com'
    port: 80
    path: '/ig/api?weather=Mountain+View'

  http.get options, (res) ->



app.configure () ->
  app.use express.bodyParser()
  app.use express.methodOverride()
  app.use express.static(__dirname + '/public')
  app.use express.errorHandler( {dumpExceptions:true, showStack: true} )


app.get '/home', (req, res) ->
  async.parallel
    one: (callback) -> setTimeout( (() -> callback(null, 'one')), 200)
    two: (callback) -> setTimeout( (() -> callback(null, 'two')), 100)
  ,
  (err, results) ->
    res.send('Oh, hello there, you silly windows box. ' + results)

app.get '/log/:word', (req, res) ->
  word = req.params.word
  redis.incr word, (err, wordCount) ->
    res.send word + ': ' + wordCount

app.listen(3001)

