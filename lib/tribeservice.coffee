uuid = require('node-uuid')

class TribeService
  constructor: (@redis) ->
    console.log 'created tribe service'
    
  createTribe: (name, success, failure) =>
    @redis.sadd 'tribe-names', name, (err, numberAdded) =>
      if err?
        console.log 'redis error creating tribe'
        console.log err
        failure 'unknown error'
        return

      if numberAdded == 0
        console.log 'tribe alredy exists: ' + name
        failure 'That name is already in use!'
      else
        @persistTribe name, success, failure

  persistTribe: (name, success, failure) =>
    tribe = {}
    tribe.name = name
    tribe.id = uuid()

    @redis.set 'tribes:' + tribe.name, tribe.id, (err, res) ->

    @redis.set 'tribes:' + tribe.id, tribe.name, (err, res) ->
      if err?
        console.log 'redis error saving name of tribe'
        failure 'unknown error'
      else
        success tribe

  getById: (id, success) =>
    @redis.get 'tribes:' + id, (err, res) =>
       success {name:res, id:id}

  getByName: (name, success) =>
    @redis.get 'tribes:' + name, (err, res) =>
      success {name: name, id: res}

exports.TribeService = TribeService