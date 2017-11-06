send_api_message = (wsocket, msg_name, args) ->

class DCJS.WebsocketTransport extends DCJS.Transport
  constructor: (@dcjs, @ws) ->
    @opened = false
    @ready = false
    @login_handler = false
    @failed_login_handler = false
    @pending_password = false
    @pending_username = false
    @on_open = false
    @queue = []

  setup: () ->
    transport = this
    @ws.onmessage = (evt) =>
      data = JSON.parse evt.data
      if data[0] == "game_msg"
        return transport.api_handler data[1], data.slice(2)
      if data[0] == "failed_login" || data[0] == "failed_registration"
        if @failed_login_handler?
          @failed_login_handler(data[1])
        else
          console.log "No failed login handler set!"
        @pending_password = false
        @pending_hash = false
        @pending_save_login = false
        return
      if data[0] == "login_salt"
        bcrypt = dcodeIO.bcrypt
        salt = data[1]
        hashed = bcrypt.hashSync(@pending_password, salt)
        @pending_password = false  # Tried it? Clear it.
        @pending_hash = hashed
        @sendMessageWithType "auth", "hashed_login", { username: @pending_username, bcrypted: hashed }
        return
      if data[0] == "login"
        console.log "Logged in as", data[1]["username"]
        if @pending_save_login && @pending_hash
          console.log "Setting cookies:", data[1]["username"], @pending_hash
          document.cookie = "dcjs_username=#{data[1]["username"]};secure"
          document.cookie = "dcjs_hash=#{@pending_hash};secure"
          @pending_hash = false
        @logged_in_as = data[1]["username"]
        if @login_handler?
          @login_handler(data[1]["username"])
        else
          console.log "No login handler set!"
        return
      if data[0] == "registration"
        consider_auto_login()

      return console.log "Unexpected message type: #{data[0]}"

    @ws.onclose = () ->
      console.log "socket closed"

    @ws.onopen = () ->
      @opened = true
      ready_check = () =>
        if transport.ws.readyState == 1
          transport.ready = true
          transport.clearQueue()
        else
          setTimeout ready_check, 0.25
      console.log "connected..."
      ready_check()
      if @on_open?
        @on_open()

  sendMessage: (msgName, args...) ->
    sendMessageWithType("game_msg", msgName, args...)

  sendMessageWithType: (msgType, msgName, args...) ->
    if @ready
      # Serialize as JSON, send
      @ws.send JSON.stringify([ msgType, msgName, args ])
    else
      @queue.push([msgType, msgName, args])
      setTimeout (() => @clearQueue()), 0.5

  clearQueue: () ->
    if @ready && @queue.length > 0
      for msg in @queue
        @ws.send JSON.stringify(msg)

  onLogin: (@login_handler) ->

  onFailedLogin: (@failed_login_handler) ->

  onOpen: (@on_open) ->
    if @opened?
      @on_open()  # Already open? Call it.

  api_handler: (msg_type, args) ->
    @handler msg_type, args

  registerAccount: (username, password) ->
    bcrypt = dcodeIO.bcrypt;
    salt = bcrypt.genSaltSync(10);
    hashed = bcrypt.hashSync(password, salt);
    @sendMessageWithType("auth", "register_account", { username: username, salt: salt, bcrypted: hashed })

  login: (username, password, save_login_info = true) ->
    @pending_password = password
    @pending_username = username
    @pending_save_login = save_login_info
    @sendMessageWithType("auth", "get_salt", { username: username })

  considerAutoLogin: () ->
    cookie_username = document.cookie.replace(/(?:(?:^|.*;\s*)dcjs_username\s*\=\s*([^;]*).*$)|^.*$/, "$1")
    cookie_hash = document.cookie.replace(/(?:(?:^|.*;\s*)dcjs_hash\s*\=\s*([^;]*).*$)|^.*$/, "$1")
    if cookie_username? && cookie_hash?
      @sendMessageWithType "auth", "hashed_login", { username: cookie_username, bcrypted: cookie_hash }
