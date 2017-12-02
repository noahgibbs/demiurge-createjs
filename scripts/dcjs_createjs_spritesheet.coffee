class DCJS.CreatejsDisplay.CreatejsSpriteSheet
  constructor: (data) ->
    [ @tilewidth, @tileheight, @images, @animations, @ss_cyclic_animations ] =
        [ data.tilewidth, data.tileheight, data.images, data.animations, data.cyclic_animations ]

    images = (image.image for image in @images)
    @loader_handler = () => @imagesLoaded()
    DCJS.CreatejsDisplay.loader.addHandler @loader_handler
    DCJS.CreatejsDisplay.loader.addImages images

    if @images[0].frame_definitions?
      @frame_definitions = []
      for image, i in @images
        # For oversize tiles, make sure their bottom left corner winds up in the right spot via reg_y param
        image_fds = ([ fd.x, fd.y, fd.width, fd.height, i, 0, fd.height - @tileheight ] for fd in image.frame_definitions)
        @frame_definitions = @frame_definitions.concat(image_fds)

    @loaded = false
    @handlers = { "complete": [] }

  detach: () ->
    DCJS.CreatejsDisplay.loader.removeHandler @loader_handler
    @handlers = { "complete": [] }

  # This started from CreateJS's SpriteSheet _calculateFrames, but it has slightly different requirements.
  # CreateJS frame specifications are an array of the form:
  #     [ x, y, width, height, image_num, reg_x, reg_y ]
  # The final three numbers are optional.
  # The Demiurge SpriteSheet objects are hashes, with fields including:
  # "firstgid", "image", "imagewidth", "imageheight", "tile_width", "tile_height", "oversize", "spacing", "margin"
  # Currently we use ManaSource-style spritesheets for terrain with a primary "natural" tile size
  # and occasional "oversize" sheets that are a multiple of this size. Oversize sprites have a tile location
  # at the "natural" size and just extend upward and rightward from there. They're only used in the "Fringe"
  # layer(s) with interesting Z coordinates - oversize objects in the layers that are always above or below
  # the agent sprites don't need to be treated specially since they don't interleave in unusual ways. They're
  # always either all-below or all-above the player and can just be handled with a lot of tiles of the natural
  # size.
  calculate_frames: () ->
    return if @frame_definitions?

    dead_frame = [ 0, 0, @tilewidth, @tileheight, 0, 0, 0 ] # Use the first natural-size tile of the first image for dead frames.
    @frame_definitions = [ dead_frame ]  # GIDs start at 1, so array offset 0 is always a dead frame.
    frame_count = 1

    for image, offset in @images
      spacing = if image.spacing? then image.spacing else 0
      margin = if image.margin? then image.margin else 0

      # Each new image specifies its starting GID. This may require pushing dead frames to pad
      # to the correct frame-number/GID.
      dead_frames = image.firstgid - frame_count
      if dead_frames < 0
        console.log "ERROR: GIDs are specified badly in tilesets! You are likely to see wrong tiles!"
      else if dead_frames > 0
        @frame_definitions.push(dead_frame) for num in [1..dead_frames]
        frame_count += dead_frames

      # Oversize images may have their own tilewidth and tileheight
      imagewidth = image.imagewidth
      #imagewidth = image.loaded_dom.width
      imageheight = image.imageheight
      imagetilewidth = image.tilewidth
      imagetileheight = image.tileheight
      reg_x = if image.reg_x? then image.reg_x else 0
      reg_y = if image.reg_y? then image.reg_y else imagetileheight - @tileheight

      y = margin
      while y <= imageheight - margin - imagetileheight
        x = margin
        while x <= imagewidth - margin - imagetilewidth
          frame_count += 1
          @frame_definitions.push [ x, y, imagetilewidth, imagetileheight, offset, reg_x, reg_y ]
          x += imagetilewidth + spacing
        y += imagetileheight + spacing


  imagesLoaded: () ->
    images = []

    # Calculate CreateJS spritesheet frame numbers
    current_cjs_offset = 0
    for image in @images
      image.loaded_dom = DCJS.CreatejsDisplay.loader.getImage image.image

      # Figure out how many frames CreateJS will extract from this image
      padded_width = parseInt(image.loaded_dom.width) + @tilewidth - 1
      padded_height = parseInt(image.loaded_dom.height) + @tileheight - 1
      cjs_width = parseInt(padded_width / @tilewidth)
      cjs_height = parseInt(padded_height / @tileheight)
      cjs_frames = cjs_width * cjs_height

      # Use current CJS offset for this image, update for next one
      image.cjs_offset = current_cjs_offset
      current_cjs_offset += cjs_frames
      images.push image.loaded_dom

    @cjs_animations = {}
    @cjs_animations[name] = @ss_anim_frames_to_cjs_anim_frames(animation) for name, animation of @animations

    @cyclic_animations = {}
    for name, animation of @ss_cyclic_animations
      tile_num = parseInt name.slice(10)  # Cut off "tile_anim_"
      new_num = @ss_frame_to_cjs_frame tile_num
      @cyclic_animations["tile_anim_#{new_num}"] = @ss_cyclic_anim_to_dcjs_cyclic_anim(animation)

    if !@frame_definitions?
      @calculate_frames()

    @sheet = new createjs.SpriteSheet frames: @frame_definitions, images: images, animations: @cjs_animations

    @loaded = true
    e = { name: "complete", source: this }
    handler(e) for handler in @handlers["complete"]

  create_sprite: () ->
    new createjs.Sprite(@sheet)

  # Handler is called on the event with an "event" object:
  #   event.name - which event
  #   event.source - object sending event
  #
  # Events:
  #   complete - all sprites loaded
  #
  addEventListener: (event, handler) ->
    if event == "complete"
      @handlers["complete"].push handler
    else
      console.error "Unknown event #{event} on spritesheet!"

  ss_anim_frames_to_cjs_anim_frames: (animation) ->
    if typeof animation == "number"
      animation
    else if animation instanceof Array
      if animation.length == 1
        [animation[0]]
      else
        { speed: animation[3], next: animation[2], frames: [(animation[0])..(animation[1])] }
    else  # complex
      frames = animation.frames
      frames = [frames] if typeof frames == "number"
      frames = @ss_anim_frames_to_cjs_anim_frames frames  # This time as Array
      { speed: animation.speed, next: animation.next, frames: frames }

  cyclic_anim_for_tile: (tile) ->
    @cyclic_animations["tile_anim_#{tile}"]

  ss_cyclic_anim_to_dcjs_cyclic_anim: (animation) ->
    anim = []

    total_duration = 0
    total_duration += section.duration for section in animation
    anim.cycle_time = total_duration * 10.0

    for section in animation
      anim.push section.frame, duration: section.duration * 10.0

    anim
