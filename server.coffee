http = require('http')
express = require('express')
redis = require('redis').createClient()
subs = require('redis').createClient()
async = require('async')
uuid = require('node-uuid')
request = require('request')
jsdom = require('jsdom')
htmlparser = require('htmlparser')
coffee4clients = require 'coffee4clients'
_ = require('underscore')

TribeService = require('./lib/tribeservice').TribeService
tribeService = new TribeService redis

app = express.createServer()

coffee4clients.createInstance {
    server: app # your express server (required)
    publicPath: __dirname + '/public' # the full path to your server root (required)
    missingAction: false # the action to forward to when a file is not found
    cache: false # whether the responses should be cached
}

io = require('socket.io').listen(app)

socketSessions = {}

LINK_PROPS = ['title', 'href', 'email']

updateLinkTitle = (socket, data) ->
  href = data.href
  id = data.id

  console.log 'update link title for link: ' + href

  request href, (error, response, body) ->
    console.log 'request complete -- have data for: ' + href
    #console.log body
    handler = new htmlparser.DefaultHandler (err, dom) ->
      if err
        console.log err
      else
        data.title = htmlparser.DomUtils.getElementsByTagName('title', dom)[0].children[0].data
        redis.set 'links:' + id + ':title', data.title, (err, res) ->
          io.sockets.emit 'link-title-updated', data
          console.log 'link title updated'
          console.log data

    parser = new htmlparser.Parser(handler)
    parser.parseComplete body

storeLink = (link, handler) ->
  redis.mset 'links:' + link.id + ':title', link.title, 'links:' + link.id + ':href', link.href, 'links:' + link.id + ':email', link.email, handler

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

handleSubmitLink = (socket, data) ->
  email = socketSessions[socket].email

  if not email
    socket.emit 'must-be-logged-in', {}
    return

  href = data.href
  title = data.title
  id = uuid()

  if not title or title == ''
    title = href

  link = {id:id, title:title, href:href, email:email}

  redis.lpush 'links', id, (err, res) ->
    console.log 'link added to links list'

  storeLink link, (err, res) ->
     console.log 'link data stored'
     console.log err
     console.log res

     if title == href
       console.log 'no title -- pulling from source'

       updateLinkTitle socket, link

  socket.emit 'link-saved', link
  io.sockets.emit 'new-link', link
  
loadLinks = (socket, ids) ->
  propsToGet = _(ids).chain().map((id) -> _.map(LINK_PROPS, (prop) -> 'links:' + id + ':' + prop)).flatten().value()
  redis.mget propsToGet, (err, res) ->
    values = {}
    _.zip(propsToGet, res).forEach (pair) ->
      values[pair[0]] = pair[1]

    links = []

    ids.forEach (id) ->
      link = {}
      link.id = id

      LINK_PROPS.forEach (prop) ->
        link[prop] = values['links:' + id + ':' + prop]

      links.push(link)

    console.log links
    
    socket.emit 'get-latest-links-complete', links

handleGetLatestLinks = (socket, data) ->
  console.log 'get latest links'

  redis.lrange 'links', 0, 10, (err, res) ->
    console.log res

    loadLinks(socket, res)

handleCreateTribe = (socket, data) ->

  handleCreateTribeSuccess = (tribe) ->
    socket.emit 'create-tribe-complete', tribe

  handleCreateTribeFailure = (message) ->
    socket.emit 'create-tribe-failure', message

  name = data.name

  tribeService.createTribe name, handleCreateTribeSuccess, handleCreateTribeFailure
  
io.sockets.on 'connection', (socket) ->
  socketSessions[socket] = {}

  socket.on 'disconnect', () ->
    socketSessions[socket] = null

  socket.on 'login', (data) ->
    handleLogin socket, data

  socket.on 'create-account', (data) ->
    handleCreateAccount socket, data

  socket.on 'submit-link', (data) ->
    handleSubmitLink socket, data

  socket.on 'get-latest-links', (data) ->
    handleGetLatestLinks socket, data

  socket.on 'create-tribe', (data) ->
    handleCreateTribe socket, data
    
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

