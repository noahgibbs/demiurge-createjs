send_api_message = (wsocket, msg_name, args) ->

class DCJS.WebsocketTransport extends DCJS.Transport
  constructor: (@dcjs, @ws) ->
    @opened = false
    @failed_login_handler = false
    @pending_password = false
    @pending_username = false

  setup: () ->
    transport = this
    @ws.onmessage = (evt) =>
      data = JSON.parse evt.data
      if data[0] == "game_msg"
        return transport.api_handler data[1], data.slice(2)
      if data[0] == "failed_login"
        if @failed_login_handler?
          @failed_login_handler(data[1])
        else
          console.log "No failed login handler set!"
        @pending_password = false
        return
      if data[0] == "login_salt"
        bcrypt = dcodeIO.bcrypt
        salt = data[1]
        hashed = bcrypt.hashSync(@pending_password, salt)
        @pending_password = false  # Tried it? Clear it.
        @sendMessageWithType "auth", "hashed_login", { username: @pending_username, bcrypted: hashed }
        return
      if data[0] == "login"
        console.log "Logged in as", data[1]
        @logged_in_as = data[1]
        return

      return console.log "Unexpected message type: #{data[0]}"

    @ws.onclose = () ->
      console.log "socket closed"

    @ws.onopen = () ->
      @opened = true
      console.log "connected..."

  sendMessage: (msgName, args...) ->
    # Serialize as JSON, send
    @ws.send JSON.stringify([ "game_msg", msgName, args ])

  sendMessageWithType: (msgType, msgName, args...) ->
    @ws.send JSON.stringify([ msgType, msgName, args ])

  on_failed_login: (@failed_login_handler) ->

  api_handler: (msg_type, args) ->
    @handler msg_type, args

  register_account: (username, password) ->
    bcrypt = dcodeIO.bcrypt;
    salt = bcrypt.genSaltSync(10);
    hashed = bcrypt.hashSync(password, salt);
    @sendMessageWithType("auth", "register_account", { username: username, salt: salt, bcrypted: hashed })

  login: (username, password) ->
    @pending_password = password
    @pending_username = username
    @sendMessageWithType("auth", "get_salt", { username: username })
