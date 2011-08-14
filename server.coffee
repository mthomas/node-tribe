http = require('http')
express = require('express')
redis = require('redis').createClient()
subs = require('redis').createClient()
async = require('async')

app = express.createServer()

io = require('socket.io').listen(app)

socketSessions = {}

handleLogin = (socket, data) ->
  email = data.email
  password = data.password

  console.log 'got login event with: ' + email + ', ' + password

  redis.hgetall 'users:' + email, (err, res) ->
    console.log 'login for ' + email + ' redis returned '
    console.log res
    if res.email == email and res.password == password
      socketSessions[socket].authenticated = true
      socketSessions[socket].email = email
      socket.emit 'login-success', {email: email}
    else
      socket.emit 'login-failure', {email: email}

handleCreateAccount = (socket, data) ->
  email = data.email
  password = data.password

  console.log 'handle create account for ' + email

  redis.sadd 'users-emails', email, (err, numberAdded) ->
    if numberAdded == 0
      console.log 'has account'
      socket.emit 'has-account', {email: email}
    else
      console.log 'Account created for: ' + email
      redis.hmset 'users:' + email, 'email', email, 'password', password, (err, res) ->
      socket.emit 'account-created', {email: email}


io.sockets.on 'connection', (socket) ->
  socketSessions[socket] = {}

  socket.on 'disconnect', () ->
    socketSessions[socket] = null

  socket.on 'login', (data) ->
    handleLogin socket, data

  socket.on 'create-account', (data) ->
    handleCreateAccount socket, data




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

