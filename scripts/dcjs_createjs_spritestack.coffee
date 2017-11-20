when_sheet_complete = (sheet, handler) ->
  return handler() if sheet.loaded
  sheet.addEventListener "complete", handler

class DCJS.CreatejsDisplay.CreatejsSpriteStack
  constructor: (@display, @sheet, data) ->
    @x = data.x || 0
    @y = data.y || 0
    @layers = {}
    @layer_order = []
    @width = data.width
    @height = data.height
    @name = data.name
    @sprite_table = {}
    @sprite_ctr = 0
    @cur_cyclic_animations = {}
    @cur_played_animations = {}
    @sheet_complete = false
    @detached = false

    unless DCJS.CreatejsDisplay._cyclicTimerStart?
      DCJS.CreatejsDisplay._cyclicTimerStart = (new Date()).getTime()

    when_sheet_complete @sheet, () =>
      return if @detached
      @sheet_complete = true
      stack_y = parseInt(Math.random() * 30000)  # Fix for an obscure agents-walk-through-each-other visual bug
      for layer in data.layers
        continue unless layer.visible

        @layer_order.push layer.name
        container = new createjs.Container
        container.alpha = layer.opacity
        container.z = layer.z
        container.stack_name = @name
        if layer.z != 0  # If not fringe layer
          @display.add_to_layer_container(container)

        @layers[layer.name] = { sprites: [], container: container, data: layer.data, z: layer.z, stack_y: stack_y }
        stack_y += 1

      @handleExposure()

      counter = 0
      @tick_listener = createjs.Ticker.addEventListener "tick", () =>
        counter++
        for sprite_name, anim of @cur_cyclic_animations
          sprite = @sprite_table[sprite_name]
          @_cyclicAnimationHandler sprite, anim

  detach: () ->
    Tween.removeTweens(this)
    createJS.Ticker.removeEventListener(@tick_listener)
    @detached = true

  # The "exposure" means the window the player can see of the
  # conceptually gigantic world.  The exposure data structure contains
  # the center of the view (called "x" and "y") and the visible width
  # and height. So if the player can see from 0 to 640 pixels in x and
  # from 0 to 480 pixels in y, the structure would be { x: 320, y:
  # 240, width: 640, height: 480 }.

  # handleExposure does the appropriate transforming for this, but
  # also makes sure we can portray the world with a reasonably small
  # number of sprites. For instance a 640 x 480 window of 32x32
  # sprites would be 20x15 blocks, or around 300 sprites/layer (we can
  # actually see 21x16 when scrolling, or 336 sprites/layer.) However,
  # if this 20x15 window was into a 2000-block by 1500-block world, we
  # would need 3 million sprites if we kept them all around all the
  # time. Instead, we can reuse our 336-ish sprites/layer as we move
  # around and change what block they show to keep the total number of
  # sprites approximately constant.

  # A "zone", in local parlance, is a location which may contain
  # multiple spritestacks. A zone isn't even required to use tiles or
  # sprites, it could use a clickable map or a text interface or
  # something. But a tile-based zone will normally contain at least
  # one spritestack for the terrain, and may contain others. It's also
  # possible for the number and type of spritestacks to change at
  # random times - we could dynamically load a new chunk of map, add a
  # new spritestack for an event or whatever.

  # You know what's hard? Coordinate systems. Let's name some of ours
  # to make this less overwhelmingly awful. Most of the coordinates
  # for this are measured in whole integers.

  # Screen coordinates: measured in pixels, goes from 0-639 and 0-479, or equivalent for other resolutions. Matches EaselJS coords.
  # Screen tile coordinates: measured in tiles, goes from 0-19 and 0-14 or equivalent for other resolutions or tile sizes.
  # Spritestack-relative coordinates: measured in pixels from the upper left corner of the spritestack.
  # Spritestack-relative tile coordinates: measured in tiles from the upper left corner of the spritestack.
  # Zone coordinates: measured in pixels, may be very large. A spritestack isn't required to
  #   line up with the tile coordinates of the zone, other spritestacks or anything else, though it usually will.
  #   Zone coordinates are used to lay out multiple sprite stacks within a single area, or just one if there's only one.
  #   In the degenerate single-spritestack case, these are generally the same as that stack's stack-relative coordinates.

  # It should be allowed for the exposure coordinates to not match the
  # zone or spritestack coordinates in various ways - scaling,
  # reflection and so on. But that's being left for later. However,
  # the exposure is given in terms of the center in order to
  # facilitate later scaling.

  handleExposure: () ->
    return unless @sheet_complete
    return if @detached  # Stop handling exposures when we're hiding the stack
    exposure = @display.exposure
    @x = parseInt(@x)   # Upper left corner of the spritestack in zone coordinates
    @y = parseInt(@y)
    exposure.x = parseInt(exposure.x) # Center of the screen in zone coordinates
    exposure.y = parseInt(exposure.y)

    # Calculate upper-left and lower-right corner of the screen in zone coordinates
    exp_start_x = exposure.x - @display.display_width / 2
    exp_start_y = exposure.y - @display.display_height / 2
    exp_end_x = exposure.x + @display.display_width / 2
    exp_end_y = exposure.y + @display.display_height / 2

    for layer_name in @layer_order
      layer = @layers[layer_name]
      if layer.z == 0  # For Fringe, adjust the transform of each sprite
        if layer.sprites?
          for sprite_row in layer.sprites
            for sprite in sprite_row
              if sprite?
                sprite.setTransform @x - exp_start_x + sprite.w_coord * @sheet.tilewidth, @y - exp_start_y + sprite.h_coord * @sheet.tileheight
        @display.sort_fringe_container()
      else # For non-Fringe, just set the container transform
        layer.container.setTransform @x - exp_start_x, @y - exp_start_y

    # Spritestack-relative tile coordinates of lowest visible tile
    start_tile_x = parseInt((exp_start_x - @x) / @sheet.tilewidth)
    start_tile_x = Math.max(start_tile_x, 0)
    start_tile_y = parseInt((exp_start_y - @y) / @sheet.tileheight)
    start_tile_y = Math.max(start_tile_y, 0)

    # Offset of highest visible tile
    end_tile_x = parseInt((exp_start_x - @x + exposure.width + @sheet.tilewidth - 1) / @sheet.tilewidth)
    end_tile_x = Math.min(end_tile_x, @width - 1)
    end_tile_y = parseInt((exp_start_y - @y + exposure.height + @sheet.tileheight - 1) / @sheet.tileheight)
    end_tile_y = Math.min(end_tile_y, @height - 1)

    # If the tiling starts at the same x and y location, we've already adjusted all the sprites
    # for visibility. We're cool. Return.
    if start_tile_x == @last_start_tile_x && start_tile_y == @last_start_tile_y && end_tile_x == @last_end_tile_x && end_tile_y == @last_end_tile_y
      return
    @last_start_tile_x = start_tile_x
    @last_start_tile_y = start_tile_y
    @last_end_tile_x = end_tile_x
    @last_end_tile_y = end_tile_y

    # How many tiles high and wide might be exposed at most?
    width_tiles = end_tile_x - start_tile_x + 1
    height_tiles = end_tile_y - start_tile_y + 1

    if start_tile_y > end_tile_y || start_tile_x > end_tile_x
      console.log("Nothing being displayed: x: #{@x} y: #{@y} ex: #{exposure.x} ey: #{exposure.y}")
      return

    for layer_name in @layer_order
      layer = @layers[layer_name]
      if layer.sprites is undefined
        layer.sprites = []
      sprites = layer.sprites
      ld = layer.data

      for h in [start_tile_y..end_tile_y]
        h_ctr = h - start_tile_y
        sprites[h_ctr] = sprites[h_ctr] || []
        for w in [start_tile_x..end_tile_x]
          w_ctr = w - start_tile_x
          sprite = sprites[h_ctr][w_ctr]
          unless sprite
            name = "sprite:#{++@sprite_ctr}"
            sprite = sprites[h_ctr][w_ctr] = @sheet.create_sprite()
            sprite.set name: name
            @sprite_table[name] = sprite
            sprites[h_ctr][w_ctr] = sprite
            if layer.z == 0 # Fringe layer
              sprite.stack_y = layer.stack_y
              sprite.w_coord = w_ctr
              sprite.h_coord = h_ctr
              @display.fringe_container.addChild sprite
            else
              layer.container.addChild sprite

          if ld[h] is undefined
            console.log "Illegal height: #{h} in spritesheet #{@name} in loop #{start_tile_y} -> #{end_tile_y}!"

          if ld[h][w] is 0
            sprite.visible = false
          else
            sprite.visible = true
            sprite.gotoAndStop ld[h][w]
            if layer.z == 0
              sprite.setTransform @x - exp_start_x + w * @sheet.tilewidth, @y - exp_start_y + h * @sheet.tileheight
            else
              sprite.setTransform w * @sheet.tilewidth, h * @sheet.tileheight
          @_setCyclicAnimationHandler(sprite, ld[h][w], h, w)
    @display.sort_fringe_container()

  animateTile: (layer_name, h, w, anim) ->
    when_sheet_complete @sheet, () =>
      return if @detached
      layer = @layers[layer_name]
      return if h < @last_start_tile_y || w < @last_start_tile_x
      return if h > @last_end_tile_y || w > @last_end_tile_x
      sprite = layer.sprites[h][w]

      # Don't try cyclic animations and createjs animations at the same time
      console.log "Deleting cyclic anim (animateTile)" if @cur_cyclic_animations[sprite.name]?
      delete @cur_cyclic_animations[sprite.name]

      # Track createjs animations for this sprite
      @cur_played_animations[sprite.name] = anim
      sprite.addEventListener "animationend",
        (_1, _2, old_anim, new_anim) =>
          if new_anim == null
            delete @cur_played_animations[sprite.name]
            @_setCyclicAnimationHandler(sprite, layer.data[h][w], h, w)
          else
            @cur_played_animations[sprite.name] = new_anim
      sprite.gotoAndPlay(anim)

  # Each tile has a single "next" cyclic animation tile, or none at all.
  # This handler ends the animation if there is no next tile, or goes to the
  # next tile if there is one.
  _setCyclicAnimationHandler: (sprite, tile_num, h, w) ->
    anim = @sheet.cyclic_anim_for_tile(tile_num)
    if anim?
      @cur_cyclic_animations[sprite.name] = anim  # Overwrite previous, if any
    else
      delete @cur_cyclic_animations[sprite.name]

  # It's hard to know how long a tick will take, and we don't want to run the
  # animations unevenly when the load in the browser changes. So instead, we
  # calculate what part of the cycle we're on and set the frame appropriately.
  _cyclicAnimationHandler: (sprite, anim) ->
    now = (new Date()).getTime()
    anim_cycle_time = anim.cycle_time
    offset = (now - DCJS.CreatejsDisplay._cyclicTimerStart) % anim_cycle_time
    section_index = 0
    duration_index = 0
    while section_index < anim.length
      duration_index += anim[section_index].duration
      break if duration_index >= offset
      section_index++
    section_index = (anim.length - 1) if section_index > (anim.length - 1)
    sprite.gotoAndStop anim[section_index].frame

  teleportTo: (x, y, opts) ->
    @x = x * @sheet.tilewidth
    @y = y * @sheet.tileheight

  teleportToPixel: (x, y, opts) ->
    @x = x
    @y = y

  moveTo: (x, y, opts) ->
    new_x = x * @sheet.tilewidth
    new_y = y * @sheet.tileheight
    @moveToPixel new_x, new_y, opts

  moveToPixel: (x, y, opts) ->
    duration = opts.duration || 1.0
    when_sheet_complete @sheet, () =>
      return if @detached
      createjs.Tween.get(this)
        .to({x: x, y: y}, duration * 1000.0, createjs.Ease.linear)
        .addEventListener("change", () =>
          @handleExposure()
          @display.sort_fringe_container())
        .call (tween) =>  # on complete, set new @x and @y
          @x = x
          @y = y
