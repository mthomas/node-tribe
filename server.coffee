express = require('express')
redis = require('redis').createClient()

app = express.createServer()

app.use(express.bodyParser())

app.get '/', (req, res) ->
  res.send('Oh, hello there, you silly windows box.')

app.get '/log/:word', (req, res) ->
  word = req.params.word
  redis.incr word, (err, wordCount) ->
    res.send word + ': ' + wordCount

app.listen(3001)