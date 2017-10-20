# The top-level DCJS library acts as a router between the Transport, the Display,
# the app and local UI and whatever else is necessary.

class window.DCJS
  setTransport: (transport) ->
    @transport = transport
  setDisplay: (display) ->
    @display = display
  setSimulation: (simulation) ->
    @simulation = simulation

  getTransport: () -> @transport
  getDisplay: () -> @display
  setup: (options = {}) ->
    dcjs_obj = this
    @transport.setHandler (msgName, args) -> dcjs_obj.gotTransportCall(msgName, args)
    @transport.setup()
    @display.setup()
    @simulation.setup()

  gotTransportCall: (msgName, args) ->
    if msgName == "start"
      console.log "Got start message! Yay!"
      return

    if msgName.slice(0, 7) == "display"
      return @display.message(msgName, args)

    if msgName.slice(0,3) == "sim"
      return @simulation.message(msgName, args)

    console.warn "Unknown message name: #{msgName}, args: #{args}"


# This is the parent class of Transport implementations for DCJS.
# Transports like Ajax, WebSockets, and record/playback would
# inherit from this class.
class DCJS.Transport
  constructor: (@dcjs) ->
  setup: () ->

  # Accepts a function like: transportHandler(apiCallName, argArray)
  # This handler is called by the Transport when a message is received from
  # the server
  setHandler: (@handler) ->

  sendMessage: (msgName, args...) ->

# This is the parent class of Display implementations for DCJS.
class DCJS.Display
  constructor: (@dcjs) ->
  setup: () ->
  message: (messageType, argArray) ->

class DCJS.Simulation
  constructor: (@dcjs) ->
  setup: () ->
  message: (messageType, argArray) ->
    if messageType == "simNotification"
      @notification(argArray[0])
    else
      console.warn "Unknown simulation message type: #{messageType}!"
  notification: (data) ->
    console.log "Implement a DCJS.Simulation subclass to do something with your notifications!"
