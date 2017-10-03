send_api_message = (ws, msg_name, args) ->
  # Serialize as JSON, send
  msg_data = JSON.stringify([ "game_msg", msg_name, args ])
  ws.send msg_data

class DCJS.WebsocketTransport extends DCJS.Transport
  constructor: (@dcjs, @ws) ->

  setup: () ->
    transport = this
    ws.onmessage = (evt) ->
      data = JSON.parse evt.data
      if data[0] != "game_msg"
        return console.log "Unexpected message type: #{data[0]}"

      transport.api_handler data[1], data.slice(2)

    ws.onclose = () ->
      console.log "socket closed"

    ws.onopen = () ->
      console.log "connected..."

  sendMessage: (msgName, args...) ->
    send_api_message(@ws, msgName, args)

  api_handler: (msg_type, args) ->
    console.log "Handling game msg: #{msg_type}", args
    if msg_type == "start"
      return send_api_message @ws, "login", ["a", "b", "c"]
    @handler msg_type, args
