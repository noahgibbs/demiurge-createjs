send_api_message = (wsocket, msg_name, args) ->
  # Serialize as JSON, send
  msg_data = JSON.stringify([ "game_msg", msg_name, args ])
  wsocket.send msg_data

class DCJS.WebsocketTransport extends DCJS.Transport
  constructor: (@dcjs, @ws) ->

  setup: () ->
    transport = this
    @ws.onmessage = (evt) ->
      data = JSON.parse evt.data
      if data[0] != "game_msg"
        return console.log "Unexpected message type: #{data[0]}"

      transport.api_handler data[1], data.slice(2)

    @ws.onclose = () ->
      console.log "socket closed"

    @ws.onopen = () ->
      console.log "connected..."

  sendMessage: (msgName, args...) ->
    send_api_message(@ws, msgName, args)

  api_handler: (msg_type, args) ->
    @handler msg_type, args
