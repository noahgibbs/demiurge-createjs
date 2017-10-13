# dcjs_createjs.coffee

messageMap = {
  "displayNewSpriteSheet": "newSpriteSheet",
  "displayNewSpriteStack": "newSpriteStack",
  "displayStartAnimation": "startAnimation",
  "displayMoveStackTo": "moveStackTo",
  "displayTeleportStackTo": "teleportStackTo",
  "displayMoveStackToPixel": "moveStackToPixel",
  "displayTeleportStackToPixel": "teleportStackToPixel",
  "displayInstantPanToPixel": "instantPanToPixel",
  "displayPanToPixel": "panToPixel",
}

class DCJS.CreatejsDisplay extends DCJS.Display
  constructor: (@dcjs, options = {}) ->
    @spritesheets = {}
    @spritestacks = {}

    @canvas = options["canvas"] || "displayCanvas"
    @display_width = $("#" + @canvas)[0].width
    @display_height = $("#" + @canvas)[0].height

    @exposure = { x: 0, y: 0, width: @display_width, height: @display_height }

  setup: () ->
    @stage = new createjs.Stage @canvas
    @layer_container = new createjs.Container
    @stage.addChild(@layer_container)
    @fringe_container = new createjs.Container
    @fringe_container.z = 0.0
    @layer_container.addChild(@fringe_container)

    createjs.Ticker.timingMode = createjs.Ticker.RAF
    createjs.Ticker.addEventListener "tick", (event) =>
      @stage.update event

  add_to_layer_container: (container) ->
    @layer_container.addChild(container)
    @sort_layer_container()   # TODO: just add this one child in sorted order

  add_to_fringe_container: (item) ->
    @fringe_container.addChild(item)
    @sort_fringe_container()   # TODO: just add this one child in sorted order

  sort_layer_container: () ->
    cur = this
    sf = (obj1, obj2) -> cur.spaceship(obj1.z, obj2.z)
    @layer_container.sortChildren(sf)

  sort_fringe_container: () ->
    cur = this
    sf = (obj1, obj2) ->
      y1 = if obj1.y then obj1.y else 0.0
      y2 = if obj2.y then obj2.y else 0.0
      cur.spaceship(y1, y2)
    @fringe_container.sortChildren(sf)

  # TODO: Figure out how to expose CreateJS events:
  #   complete  (everything complete)
  #   error     (error while loading)
  #   progress  (total queue progress)
  #   fileload  (one file loaded)
  #   fileprogress  (progress in single file)
  on_load_update: (handler) ->
    @load_handler = handler
    DCJS.CreatejsDisplay.loader.setHandler handler

  # TODO: tie this in neatly w/ on_load_update,
  # map events properly, document them
  addEventListener: (event, handler) ->

  message: (msgName, argArray) ->
    handler = messageMap[msgName]
    unless handler?
      console.warn "Couldn't handle message type #{msgName}!"
      return
    this[handler](argArray...)

  # This method takes the following keys to its argument:
  #    name: the spritesheet name
  #    images: an array of images
  #    tilewidth: the width of each tile
  #    tileheight: the height of each tile
  #    animations: an object of animation names mapped to DCJS animation specs (see animate methods)
  #
  # Here's an example:
  # {
  #   "name" => "test_humanoid_spritesheet",
  #   "tilewidth" => 64,
  #   "tileheight" => 64,
  #   "animations" => { "stand" => 1, "sit" => [2, 5], "jumpsit" => [6, 9, "sit", 200], "kersquibble" => {} },
  #   "images" => [
  #     {
  #       "firstgid" => 1,
  #       "image" => "/sprites/skeleton_walkcycle.png",
  #       "image_width" => 576,
  #       "image_height" => 256
  #     }
  # }
  #
  newSpriteSheet: (data) ->
    @spritesheets[data.name] = new DCJS.CreatejsDisplay.CreatejsSpriteSheet(data)

  # Keys in data arg:
  #     name: name of spritestack
  #     spritesheet: name of spritesheet
  #     width:
  #     height:
  #     layers: { name: "", visible: true, opacity: 1.0, data: [ [1, 2, 3], [4, 5, 6], [7, 8, 9] ] }
  newSpriteStack: (data) ->
    sheet = @spritesheets[data.spritesheet]
    unless sheet?
      console.warn "Can't find spritesheet #{data.spritesheet} for sprite #{data.name}!"
      return

    stack = new DCJS.CreatejsDisplay.CreatejsSpriteStack(this, sheet, data)
    @spritestacks[data.name] = stack

  startAnimation: (data) ->
    stack = @spritestacks[data.stack]
    stack.animateTile data.layer, data.h, data.w, data.anim

  teleportStackTo: (stack, x, y, options) ->
    stack = @spritestacks[stack]
    stack.teleportTo x, y, duration: options.duration || 1.0

  moveStackTo: (stack, x, y, options) ->
    stack = @spritestacks[stack]
    stack.moveTo x, y, duration: options.duration || 1.0

  teleportStackToPixel: (stack, x, y, options) ->
    stack = @spritestacks[stack]
    stack.teleportToPixel x, y, duration: options.duration || 1.0

  moveStackToPixel: (stack, x, y, options) ->
    stack = @spritestacks[stack]
    stack.moveToPixel x, y, duration: options.duration || 1.0

  instantPanToPixel: (x, y) ->
    @exposure = { x: x, y: y, width: @display_width, height: @display_height }

  panToPixel: (new_exp_x, new_exp_y, options) ->
    duration = options.duration || 1.0
    createjs.Tween.get(@exposure)
      .to({x: new_exp_x, y: new_exp_y}, duration * 1000.0, createjs.Ease.linear)
      .addEventListener "change", () =>
        for name, stack of @spritestacks
          stack.handleExposure()
      .call (tween) =>
        @exposure.x = new_exp_x
        @exposure.y = new_exp_y

  spaceship: (o1, o2) ->
    if o1 > o2
      1
    else if o2 > o1
      -1
    else
      0
