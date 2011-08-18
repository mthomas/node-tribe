class Homepage
  constructor: () ->
    console.log 'constructor'
    @socket = io.connect()

    @linkCache = {}

    @initTemplates()
    @initClientEvents()
    @initSocketEvents()

    @socket.emit 'get-latest-links', {}

  initTemplates: () =>
    console.log 'init templates'
    @templates = {
      link : _.template($('#link-template').html())
    }
    
  initClientEvents: () =>
    $('#create-account').click () =>
      @socket.emit 'create-account', {email: $('#email').val(), password: $('#password').val()}

    $('#login').click () =>
      @socket.emit 'login', {email: $('#login-email').val(), password: $('#login-password').val()}

    $('#submit-link').click () =>
      @socket.emit 'submit-link', {href: $('#link-href').val(), title: $('#link-title').val()}

  initSocketEvents: () =>
    @socket.on 'has-account', (data) ->
      alert 'You already have an account, silly!'

    @socket.on 'account-created', (data) ->
      alert 'account created'

    @socket.on 'login-success', (data) ->
      alert 'logged in as ' + data.email

    @socket.on 'login-failure', (data) ->
      alert 'login failed for ' + data.email

    @socket.on 'must-be-logged-in', (data) ->
      alert 'you must be logged in to do that'

    @socket.on 'link-saved', (data) ->
      # pass -- we will get the new-link event soon enough

    @socket.on 'get-latest-links-complete', (links) =>
      linkHtml = _.map links, (link) =>
        return @templates.link {'link': link}

      $("#links").html(linkHtml.join(''))

    @socket.on 'new-link', (link) =>
      linkHtml = @templates.link {'link': link}
      oldHtml = $("#links").html()
      $("#links").html(linkHtml + oldHtml)

    @socket.on 'link-title-updated', (link) ->
      $("#link-" + link.id + " .link-title").html(link.title)

$ () ->
  console.log 'init'
  homepage = new Homepage